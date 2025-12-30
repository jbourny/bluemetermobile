package com.bluemeter.bluemeter_mobile

import java.nio.ByteBuffer

/**
 * Helper class to parse and build IPv4, TCP, and UDP packets.
 * Wraps a ByteBuffer.
 */
class Packet {
    var backingBuffer: ByteBuffer? = null
    
    // IP Header fields
    var ipVersion: Int = 0
    var ipHeaderLength: Int = 0
    var protocol: Int = 0
    var sourceIpInt: Int = 0
    var destIpInt: Int = 0
    
    // TCP/UDP fields
    var sourcePort: Int = 0
    var destPort: Int = 0
    
    // TCP specific
    var seqNum: Long = 0
    var ackNum: Long = 0
    var flags: Int = 0
    var tcpHeaderLength: Int = 0
    var payloadSize: Int = 0
    
    var isTcp: Boolean = false
    var isUdp: Boolean = false

    fun set(buffer: ByteBuffer) {
        this.backingBuffer = buffer
        parse()
    }

    private fun parse() {
        val buffer = backingBuffer ?: return
        buffer.position(0)
        if (buffer.remaining() < 20) return // Too short

        val ipByte = buffer.get(0).toInt()
        ipVersion = (ipByte shr 4) and 0xF
        
        if (ipVersion == 4) {
            ipHeaderLength = (ipByte and 0xF) * 4
            protocol = buffer.get(9).toInt() and 0xFF
            sourceIpInt = buffer.getInt(12)
            destIpInt = buffer.getInt(16)

            if (protocol == 6) { // TCP
                isTcp = true
                isUdp = false
                sourcePort = buffer.getShort(ipHeaderLength).toInt() and 0xFFFF
                destPort = buffer.getShort(ipHeaderLength + 2).toInt() and 0xFFFF
                seqNum = buffer.getInt(ipHeaderLength + 4).toLong() and 0xFFFFFFFFL
                ackNum = buffer.getInt(ipHeaderLength + 8).toLong() and 0xFFFFFFFFL
                val dataOffset = (buffer.get(ipHeaderLength + 12).toInt() shr 4) and 0xF
                tcpHeaderLength = dataOffset * 4
                flags = buffer.get(ipHeaderLength + 13).toInt() and 0xFF
                payloadSize = buffer.limit() - ipHeaderLength - tcpHeaderLength
            } else if (protocol == 17) { // UDP
                isUdp = true
                isTcp = false
                sourcePort = buffer.getShort(ipHeaderLength).toInt() and 0xFFFF
                destPort = buffer.getShort(ipHeaderLength + 2).toInt() and 0xFFFF
                payloadSize = buffer.limit() - ipHeaderLength - 8
            } else {
                isTcp = false
                isUdp = false
            }
        }
    }

    val sourceIp: String
        get() = ipToString(sourceIpInt)

    val destIp: String
        get() = ipToString(destIpInt)


    fun swapSourceAndDest() {
        val tmpIp = sourceIpInt
        sourceIpInt = destIpInt
        destIpInt = tmpIp
        
        val tmpPort = sourcePort
        sourcePort = destPort
        destPort = tmpPort
    }

    fun updateTcpBuffer(newFlags: Int, newSeq: Long, newAck: Long, payload: ByteArray?) {
        val buffer = backingBuffer ?: return
        // Rebuild TCP header in backingBuffer for response
        
        // IP Header: Swap IPs
        buffer.putInt(12, sourceIpInt)
        buffer.putInt(16, destIpInt)
        
        // TCP Header: Swap Ports
        buffer.putShort(ipHeaderLength, sourcePort.toShort())
        buffer.putShort(ipHeaderLength + 2, destPort.toShort())
        
        // Seq/Ack
        buffer.putInt(ipHeaderLength + 4, newSeq.toInt())
        buffer.putInt(ipHeaderLength + 8, newAck.toInt())
        
        // Flags (keep offset 5 words = 20 bytes, clear reserved/flags, set new flags)
        val offset = 5 
        buffer.put(ipHeaderLength + 12, ((offset shl 4) and 0xF0).toByte())
        buffer.put(ipHeaderLength + 13, newFlags.toByte())
        
        // Window size (arbitrary large)
        buffer.putShort(ipHeaderLength + 14, 64000.toShort())
        
        // Checksum (zero first)
        buffer.putShort(ipHeaderLength + 16, 0.toShort())
        // Urgent pointer
        buffer.putShort(ipHeaderLength + 18, 0.toShort())
        
        // Payload
        val payloadLen = payload?.size ?: 0
        if (payload != null) {
            buffer.position(ipHeaderLength + 20)
            buffer.put(payload)
        }
        
        // Update IP Length
        val totalLen = ipHeaderLength + 20 + payloadLen
        buffer.putShort(2, totalLen.toShort())
        buffer.limit(totalLen)
        
        // Calculate Checksums
        calculateIpChecksum()
        calculateTcpChecksum(20 + payloadLen)
    }
    
    fun updateUdpBuffer(payload: ByteArray?) {
        val buffer = backingBuffer ?: return
        // IP Header: Swap IPs
        buffer.putInt(12, sourceIpInt)
        buffer.putInt(16, destIpInt)
        
        // UDP Header: Swap Ports
        buffer.putShort(ipHeaderLength, sourcePort.toShort())
        buffer.putShort(ipHeaderLength + 2, destPort.toShort())
        
        val payloadLen = payload?.size ?: 0
        val totalLen = ipHeaderLength + 8 + payloadLen
        
        // UDP Length
        buffer.putShort(ipHeaderLength + 4, (8 + payloadLen).toShort())
        // Checksum (zero)
        buffer.putShort(ipHeaderLength + 6, 0.toShort())
        
        if (payload != null) {
            buffer.position(ipHeaderLength + 8)
            buffer.put(payload)
        }
        
        // Update IP Length
        buffer.putShort(2, totalLen.toShort())
        buffer.limit(totalLen)
        
        calculateIpChecksum()
        // UDP Checksum optional, can be 0
    }

    private fun calculateIpChecksum() {
        val buffer = backingBuffer ?: return
        buffer.putShort(10, 0.toShort())
        var sum = 0
        for (i in 0 until ipHeaderLength step 2) {
            sum += buffer.getShort(i).toInt() and 0xFFFF
        }
        while ((sum shr 16) > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        buffer.putShort(10, sum.inv().toShort())
    }

    private fun calculateTcpChecksum(tcpLen: Int) {
        val buffer = backingBuffer ?: return
        var sum = 0
        // Pseudo Header
        sum += (sourceIpInt shr 16) and 0xFFFF
        sum += sourceIpInt and 0xFFFF
        sum += (destIpInt shr 16) and 0xFFFF
        sum += destIpInt and 0xFFFF
        sum += 6 // Protocol TCP
        sum += tcpLen
        
        // TCP Header + Data
        buffer.position(ipHeaderLength)
        for (i in 0 until tcpLen step 2) {
            if (i == tcpLen - 1) {
                sum += (buffer.get(ipHeaderLength + i).toInt() and 0xFF) shl 8
            } else {
                sum += buffer.getShort(ipHeaderLength + i).toInt() and 0xFFFF
            }
        }
        
        while ((sum shr 16) > 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        buffer.putShort(ipHeaderLength + 16, sum.inv().toShort())
    }
    
    companion object {
        const val TCP_FIN = 0x01
        const val TCP_SYN = 0x02
        const val TCP_RST = 0x04
        const val TCP_PSH = 0x08
        const val TCP_ACK = 0x10
        
        fun ipToString(ip: Int): String {
            return String.format("%d.%d.%d.%d",
                (ip shr 24) and 0xFF,
                (ip shr 16) and 0xFF,
                (ip shr 8) and 0xFF,
                ip and 0xFF)
        }
    }
}
