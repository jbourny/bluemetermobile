package com.bluemeter.bluemeter_mobile

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.IOException
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.DatagramChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

class PacketCaptureService : VpnService() {
    private var mInterface: ParcelFileDescriptor? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val flushExecutor: ScheduledExecutorService = Executors.newSingleThreadScheduledExecutor()
    private var flushTask: java.util.concurrent.ScheduledFuture<*>? = null
    private var isRunning = false
    
    private lateinit var tcpProxy: TcpProxy
    private val outputQueue = ConcurrentLinkedQueue<ByteBuffer>()
    
    // Object Pools
    private val bufferPool = ConcurrentLinkedQueue<ByteBuffer>()
    private val packetPool = ConcurrentLinkedQueue<Packet>()
    
    private fun obtainBuffer(size: Int): ByteBuffer {
        val buffer = bufferPool.poll()
        if (buffer != null && buffer.capacity() >= size) {
            buffer.clear()
            return buffer
        }
        return ByteBuffer.allocate(if (size > 4096) size else 4096)
    }
    
    private fun recycleBuffer(buffer: ByteBuffer) {
        bufferPool.offer(buffer)
    }
    
    private fun obtainPacket(): Packet {
        return packetPool.poll() ?: Packet()
    }
    
    private fun recyclePacket(packet: Packet) {
        packet.backingBuffer = null
        packetPool.offer(packet)
    }
    
    private val dataBuffer = java.io.ByteArrayOutputStream()
    private val bufferLock = Any()
    
    // Key: SourceIP:SourcePort
    private val udpChannels = HashMap<String, DatagramChannel>() 

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") {
            stopCapture()
            return START_NOT_STICKY
        }
        startCapture()
        return START_STICKY
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }

    // Signature to detect game traffic: 00 63 33 53 42 00
    private val serverSignature = byteArrayOf(0x00, 0x63, 0x33, 0x53, 0x42, 0x00)
    private val validGameSessions = ConcurrentHashMap.newKeySet<String>()

    private fun startCapture() {
        if (isRunning) return
        isRunning = true
        
        // Schedule flush task
        flushTask = flushExecutor.scheduleAtFixedRate({
            flushData()
        }, 50, 50, TimeUnit.MILLISECONDS)

        tcpProxy = TcpProxy(this, ::obtainBuffer) { source, data ->
            // Filter out HTTPS traffic
            if (source.contains("destPort=443")) return@TcpProxy

            // Check for game session
            if (!validGameSessions.contains(source)) {
                if (indexOf(data, serverSignature) != -1) {
                    validGameSessions.add(source)
                    Log.i("BlueMeter", "Game session detected: $source")
                }
            }

            // Only forward data from valid game sessions
            if (validGameSessions.contains(source)) {
                synchronized(bufferLock) {
                    dataBuffer.write(data)
                    // Flush immediately if buffer gets too large to avoid Binder transaction limit
                    if (dataBuffer.size() > 200 * 1024) {
                        flushData()
                    }
                }
            }
        }

        val builder = Builder()
        builder.setSession("BlueMeter")
        builder.addAddress("10.0.0.2", 24)
        builder.addRoute("0.0.0.0", 0)
        builder.setMtu(1500)
        
        try {
            mInterface = builder.establish()
            executor.submit { runCaptureLoop() }
        } catch (e: Exception) {
            Log.e("BlueMeter", "Failed to establish VPN", e)
            stopSelf()
        }
    }

    private fun stopCapture() {
        isRunning = false
        flushTask?.cancel(false)
        flushTask = null
        try {
            mInterface?.close()
        } catch (e: Exception) {
            Log.e("BlueMeter", "Error closing VPN interface", e)
        }
        mInterface = null
        udpChannels.values.forEach { try { it.close() } catch (e: Exception) {} }
        udpChannels.clear()
    }

    private fun flushData() {
        synchronized(bufferLock) {
            if (dataBuffer.size() > 0) {
                val intent = Intent("com.bluemeter.mobile.PACKET_DATA")
                intent.putExtra("data", dataBuffer.toByteArray())
                intent.setPackage(packageName)
                sendBroadcast(intent)
                dataBuffer.reset()
            }
        }
    }

    private fun indexOf(data: ByteArray, pattern: ByteArray): Int {
        if (pattern.isEmpty()) return 0
        if (data.size < pattern.size) return -1
        
        for (i in 0..data.size - pattern.size) {
            var found = true
            for (j in pattern.indices) {
                if (data[i + j] != pattern[j]) {
                    found = false
                    break
                }
            }
            if (found) return i
        }
        return -1
    }

    private fun runCaptureLoop() {
        val vpnInterface = mInterface ?: return
        val inputStream = FileInputStream(vpnInterface.fileDescriptor)
        val outputStream = FileOutputStream(vpnInterface.fileDescriptor)
        
        // Thread to read from TUN to avoid blocking the main loop
        val inputQueue = ConcurrentLinkedQueue<ByteBuffer>()
        val readerThread = Thread {
            val readBuffer = ByteBuffer.allocate(32767)
            while (isRunning && mInterface != null) {
                try {
                    val len = inputStream.read(readBuffer.array())
                    if (len > 0) {
                        val packetData = obtainBuffer(len)
                        packetData.put(readBuffer.array(), 0, len)
                        packetData.flip()
                        inputQueue.add(packetData)
                    }
                } catch (e: Exception) {
                    if (isRunning) Log.e("BlueMeter", "Error reading TUN", e)
                    break
                }
            }
        }
        readerThread.start()

        while (isRunning && mInterface != null) {
            try {
                // 1. Process Input from TUN
                var packetData = inputQueue.poll()
                while (packetData != null) {
                    val packet = obtainPacket()
                    packet.set(packetData)
                    
                    if (packet.ipVersion == 4) {
                        if (packet.protocol == 6) { // TCP
                            tcpProxy.processPacket(packet, outputQueue)
                        } else if (packet.protocol == 17) { // UDP
                            processUdpPacket(packet)
                        }
                    }
                    
                    recyclePacket(packet)
                    recycleBuffer(packetData)
                    
                    packetData = inputQueue.poll()
                }
                
                // 2. Process TCP Network Events
                tcpProxy.poll(outputQueue)
                
                // 3. Process UDP Network Events
                pollUdpSockets()
                
                // 4. Write Output to TUN
                var outPacket = outputQueue.poll()
                while (outPacket != null) {
                    outputStream.write(outPacket.array(), 0, outPacket.limit())
                    recycleBuffer(outPacket)
                    outPacket = outputQueue.poll()
                }
                
                // Sleep a tiny bit to save CPU if idle
                Thread.sleep(1) // Reduced sleep time for responsiveness
                
            } catch (e: Exception) {
                Log.e("BlueMeter", "Capture loop error", e)
            }
        }
        
        try {
            readerThread.join()
        } catch (e: InterruptedException) {}
    }

    private fun processUdpPacket(packet: Packet) {
        val key = "${packet.sourceIp}:${packet.sourcePort}"
        var channel = udpChannels[key]
        
        if (channel == null) {
            try {
                channel = DatagramChannel.open()
                channel.configureBlocking(false)
                protect(channel.socket())
                channel.connect(InetSocketAddress(packet.destIp, packet.destPort))
                udpChannels[key] = channel
            } catch (e: IOException) {
                Log.e("BlueMeter", "UDP Error", e)
                return
            }
        }
        
        try {
            val buffer = packet.backingBuffer
            if (buffer != null) {
                buffer.position(packet.ipHeaderLength + 8)
                val payload = buffer.slice()
                channel.write(payload)
            }
        } catch (e: IOException) {
            Log.e("BlueMeter", "UDP Write Error", e)
        }
    }
    
    private fun pollUdpSockets() {
        val buffer = obtainBuffer(32767)
        val it = udpChannels.entries.iterator()
        while (it.hasNext()) {
            val entry = it.next()
            val channel = entry.value
            val keyParts = entry.key.split(":")
            val appIp = keyParts[0]
            val appPort = keyParts[1].toInt()
            
            try {
                buffer.clear()
                if (channel.read(buffer) > 0) {
                    buffer.flip()
                    val dataSize = buffer.remaining()
                    val data = ByteArray(dataSize)
                    buffer.get(data)
                    
                    val remoteAddr = channel.remoteAddress as InetSocketAddress
                    val remoteIp = remoteAddr.address.hostAddress
                    val remotePort = remoteAddr.port
                    
                    val outBuffer = obtainBuffer(20 + 8 + dataSize)
                    
                    // IP Header
                    outBuffer.put(0, 0x45.toByte())
                    outBuffer.putShort(2, (20 + 8 + dataSize).toShort()) // Total Length
                    outBuffer.putShort(4, 0) // ID
                    outBuffer.putShort(6, 0) // Flags
                    outBuffer.put(8, 64.toByte()) // TTL
                    outBuffer.put(9, 17.toByte()) // Protocol UDP
                    outBuffer.putShort(10, 0) // Checksum
                    
                    val sourceIpParts = remoteIp.split(".")
                    val destIpParts = appIp.split(".")
                    
                    for (i in 0..3) outBuffer.put(12 + i, sourceIpParts[i].toInt().toByte())
                    for (i in 0..3) outBuffer.put(16 + i, destIpParts[i].toInt().toByte())
                    
                    // UDP Header
                    outBuffer.putShort(20, remotePort.toShort())
                    outBuffer.putShort(22, appPort.toShort())
                    outBuffer.putShort(24, (8 + dataSize).toShort())
                    outBuffer.putShort(26, 0) // Checksum
                    
                    outBuffer.position(28)
                    outBuffer.put(data)
                    outBuffer.flip()
                    
                    // Calculate IP Checksum
                    var sum = 0
                    for (i in 0 until 20 step 2) {
                        sum += outBuffer.getShort(i).toInt() and 0xFFFF
                    }
                    while ((sum shr 16) > 0) {
                        sum = (sum and 0xFFFF) + (sum shr 16)
                    }
                    outBuffer.putShort(10, sum.inv().toShort())
                    
                    outputQueue.add(outBuffer)
                }
            } catch (e: IOException) {
                // Log.e("BlueMeter", "UDP Read Error", e)
            }
        }
        recycleBuffer(buffer)
    }
}
