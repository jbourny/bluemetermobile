package com.bluemeter.bluemeter_mobile

import android.net.VpnService
import android.util.Log
import java.io.IOException
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.SelectionKey
import java.nio.channels.Selector
import java.nio.channels.SocketChannel
import java.util.concurrent.ConcurrentHashMap

class TcpProxy(
    private val vpnService: VpnService, 
    private val bufferProvider: (Int) -> ByteBuffer,
    private val onDataReceived: (String, ByteArray) -> Unit
) {
    private val selector: Selector = Selector.open()
    private val sessions = ConcurrentHashMap<SessionKey, Session>()
    private val readBuffer = ByteBuffer.allocate(4096)

    data class SessionKey(
        val sourceIp: Int,
        val sourcePort: Int,
        val destIp: Int,
        val destPort: Int
    )

    fun processPacket(packet: Packet, outputQueue: java.util.Queue<ByteBuffer>) {
        val key = SessionKey(packet.sourceIpInt, packet.sourcePort, packet.destIpInt, packet.destPort)
        var session = sessions[key]

        if (packet.flags and Packet.TCP_SYN != 0) {
            if (session == null) {
                session = Session(packet.sourceIpInt, packet.sourcePort, packet.destIpInt, packet.destPort)
                sessions[key] = session
                try {
                    val channel = SocketChannel.open()
                    channel.configureBlocking(false)
                    vpnService.protect(channel.socket())
                    channel.connect(InetSocketAddress(ipToString(packet.destIpInt), packet.destPort))
                    channel.register(selector, SelectionKey.OP_CONNECT, session)
                    session.channel = channel
                    session.state = SessionState.SYN_RECEIVED
                    session.clientSeq = packet.seqNum + 1
                    session.mySeq = 1000 // Random start
                    // Log.d("TcpProxy", "New Session: $key")
                } catch (e: IOException) {
                    // Log.e("TcpProxy", "Failed to connect", e)
                    sessions.remove(key)
                    return
                }
            }
        } else if (session != null) {
            if (packet.flags and Packet.TCP_FIN != 0) {
                session.state = SessionState.FIN_WAIT
                // Send FIN to remote
                try {
                    session.channel?.close() 
                } catch (e: Exception) {}
                // Ack the FIN
                session.clientSeq = packet.seqNum + 1
                sendTcpPacket(session, Packet.TCP_ACK, null, outputQueue)
                sessions.remove(key) 
                return
            }
            
            if (packet.flags and Packet.TCP_ACK != 0) {
                // Data?
                if (packet.payloadSize > 0) {
                    val payload = ByteArray(packet.payloadSize)
                    val buffer = packet.backingBuffer
                    if (buffer != null) {
                        buffer.position(packet.ipHeaderLength + packet.tcpHeaderLength)
                        buffer.get(payload)
                        
                        try {
                            session.channel?.write(ByteBuffer.wrap(payload))
                            session.clientSeq += packet.payloadSize
                            // Send ACK
                            sendTcpPacket(session, Packet.TCP_ACK, null, outputQueue)
                        } catch (e: IOException) {
                            // Log.e("TcpProxy", "Write error", e)
                            sessions.remove(key)
                        }
                    }
                }
            }
        }
    }

    fun poll(outputQueue: java.util.Queue<ByteBuffer>) {
        if (selector.selectNow() == 0) return

        val iterator = selector.selectedKeys().iterator()
        while (iterator.hasNext()) {
            val key = iterator.next()
            iterator.remove()
            val session = key.attachment() as Session
            val sessionKey = SessionKey(session.sourceIp, session.sourcePort, session.destIp, session.destPort)

            try {
                if (key.isConnectable) {
                    val channel = key.channel() as SocketChannel
                    if (channel.finishConnect()) {
                        key.interestOps(SelectionKey.OP_READ)
                        session.state = SessionState.ESTABLISHED
                        // Send SYN-ACK to client
                        sendTcpPacket(session, Packet.TCP_SYN or Packet.TCP_ACK, null, outputQueue)
                        session.mySeq++
                    }
                } else if (key.isReadable) {
                    val channel = key.channel() as SocketChannel
                    readBuffer.clear()
                    val read = channel.read(readBuffer)
                    if (read == -1) {
                        // Remote closed
                        key.cancel()
                        sessions.remove(sessionKey)
                        // Send FIN to client
                        sendTcpPacket(session, Packet.TCP_FIN or Packet.TCP_ACK, null, outputQueue)
                    } else if (read > 0) {
                        readBuffer.flip()
                        val data = ByteArray(read)
                        readBuffer.get(data)
                        
                        onDataReceived(sessionKey.toString(), data)

                        // Forward to client
                        sendTcpPacket(session, Packet.TCP_ACK, data, outputQueue)
                        session.mySeq += read
                    }
                }
            } catch (e: IOException) {
                // Log.e("TcpProxy", "Selector error", e)
                key.cancel()
                sessions.remove(sessionKey)
            }
        }
    }

    private fun sendTcpPacket(session: Session, flags: Int, data: ByteArray?, outputQueue: java.util.Queue<ByteBuffer>) {
        val dataSize = data?.size ?: 0
        val bufferSize = if (dataSize + 100 > 2048) dataSize + 100 else 2048
        val buffer = bufferProvider(bufferSize)
        
        // IP Header
        buffer.put(0, 0x45.toByte())
        buffer.putShort(2, 0) // Total Length
        buffer.putShort(4, 0) // ID
        buffer.putShort(6, 0) // Flags
        buffer.put(8, 64.toByte()) // TTL
        buffer.put(9, 6.toByte()) // Protocol TCP
        buffer.putShort(10, 0) // Checksum
        
        // Source IP (Remote Server) -> Dest IP (Local Device)
        // session.destIp is the remote server IP (int)
        // session.sourceIp is the local device IP (int)
        
        buffer.putInt(12, session.destIp)
        buffer.putInt(16, session.sourceIp)
        
        // TCP Header
        val ipHeaderLen = 20
        buffer.putShort(ipHeaderLen, session.destPort.toShort())
        buffer.putShort(ipHeaderLen + 2, session.sourcePort.toShort())
        
        buffer.putInt(ipHeaderLen + 4, session.mySeq.toInt())
        buffer.putInt(ipHeaderLen + 8, session.clientSeq.toInt())
        
        // Offset 5 (20 bytes)
        buffer.put(ipHeaderLen + 12, (0x50).toByte())
        buffer.put(ipHeaderLen + 13, flags.toByte())
        buffer.putShort(ipHeaderLen + 14, 64000.toShort())
        buffer.putShort(ipHeaderLen + 16, 0) // Checksum
        buffer.putShort(ipHeaderLen + 18, 0) // Urgent
        
        if (data != null) {
            buffer.position(ipHeaderLen + 20)
            buffer.put(data)
        }
        
        val totalLen = ipHeaderLen + 20 + (data?.size ?: 0)
        buffer.putShort(2, totalLen.toShort())
        buffer.limit(totalLen)
        
        // IP Checksum
        buffer.putShort(10, 0)
        var sum = 0
        for (i in 0 until 20 step 2) {
            sum += buffer.getShort(i).toInt() and 0xFFFF
        }
        while ((sum shr 16) > 0) sum = (sum and 0xFFFF) + (sum shr 16)
        buffer.putShort(10, sum.inv().toShort())
        
        // TCP Checksum
        sum = 0
        // Pseudo Header
        sum += (buffer.getInt(12) shr 16) and 0xFFFF
        sum += buffer.getInt(12) and 0xFFFF
        sum += (buffer.getInt(16) shr 16) and 0xFFFF
        sum += buffer.getInt(16) and 0xFFFF
        sum += 6
        sum += (20 + (data?.size ?: 0))
        
        for (i in 0 until (20 + (data?.size ?: 0)) step 2) {
             if (i == (20 + (data?.size ?: 0)) - 1) {
                sum += (buffer.get(20 + i).toInt() and 0xFF) shl 8
            } else {
                sum += buffer.getShort(20 + i).toInt() and 0xFFFF
            }
        }
        while ((sum shr 16) > 0) sum = (sum and 0xFFFF) + (sum shr 16)
        buffer.putShort(ipHeaderLen + 16, sum.inv().toShort())
        
        outputQueue.add(buffer)
    }

    private fun ipToString(ip: Int): String {
        return String.format("%d.%d.%d.%d",
            (ip shr 24) and 0xFF,
            (ip shr 16) and 0xFF,
            (ip shr 8) and 0xFF,
            ip and 0xFF)
    }

    data class Session(
        val sourceIp: Int,
        val sourcePort: Int,
        val destIp: Int,
        val destPort: Int,
        var channel: SocketChannel? = null,
        var state: SessionState = SessionState.CLOSED,
        var clientSeq: Long = 0,
        var mySeq: Long = 0
    )

    enum class SessionState {
        CLOSED, SYN_RECEIVED, ESTABLISHED, FIN_WAIT
    }
}
