import 'dart:typed_data';
// import 'package:es_compression/zstd.dart';
import 'package:zstd/zstd.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'protocol/blue_protocol.dart';

class PacketAnalyzer {
  static const int _zstdMagic = 0xFD2FB528;
  static const int _skippableMagicMin = 0x184D2A50;
  static const int _skippableMagicMax = 0x184D2A5F;

  // Method IDs
  static const int _methodSyncToMeDeltaInfo = 0x0000002E;
  static const int _methodSyncNearDeltaInfo = 0x0000002D;
  static const int _serviceUuid = 0x63335342; // 0x0000000063335342

  final Function(int damage, bool isCrit) onDamageDetected;
  final BytesBuilder _buffer = BytesBuilder();

  PacketAnalyzer({required this.onDamageDetected});

  void processPacket(Uint8List chunk) {
    _buffer.add(chunk);

    while (true) {
      final bytes = _buffer.toBytes();
      if (bytes.length < 4) break; // Need at least size header

      // Peek packet size (first 4 bytes)
      final packetSize = ByteData.sublistView(bytes, 0, 4).getUint32(0, Endian.big);

      if (packetSize < 4 || packetSize > 10000000) {
         debugPrint("Invalid packet size: $packetSize. Buffer len: ${bytes.length}. Clearing buffer.");
         _buffer.clear();
         break;
      }

      // Check if we have the full packet (packetSize includes the header itself)
      if (bytes.length < packetSize) {
        debugPrint("Waiting for more data. Have: ${bytes.length}, Need: $packetSize");
        break; // Wait for more data
      }

      // Extract the full packet
      final packetData = bytes.sublist(0, packetSize);
      
      // Remove processed bytes from buffer
      final remaining = bytes.sublist(packetSize);
      _buffer.clear();
      _buffer.add(remaining);

      // Process the extracted packet body
      _parseSinglePacket(packetData, packetSize);
    }
  }

  void _parseSinglePacket(Uint8List packetData, int expectedSize) {
    final packetReader = ByteReader(packetData);
    if (packetReader.remaining < 4) return;

    final sizeAgain = packetReader.readUInt32BE();
    if (sizeAgain != expectedSize) {
        debugPrint("Packet size mismatch: $sizeAgain != $expectedSize");
        final dump = packetData.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
        debugPrint("Packet dump: $dump");
        return;
    }

    if (packetReader.remaining < 2) return;
    final packetType = packetReader.readUInt16BE();
    final isZstdCompressed = (packetType & 0x8000) != 0;
    final msgTypeId = packetType & 0x7FFF;

    debugPrint("Parsed packet: Type=$msgTypeId, Compressed=$isZstdCompressed, Size=$expectedSize");

    if (msgTypeId == 2) { // Notify
      _processNotifyMsg(packetReader, isZstdCompressed);
    } else if (msgTypeId == 6) { // FrameDown
      _processFrameDown(packetReader, isZstdCompressed);
    }
  }

  void _processNotifyMsg(ByteReader reader, bool isZstdCompressed) {
    if (reader.remaining < 16) return; 
    
    final serviceUuid = reader.readUInt64BE();
    reader.readUInt32BE(); // stubId
    final methodId = reader.readUInt32BE();

    if (serviceUuid.toInt() != _serviceUuid) {
        // debugPrint("Service UUID mismatch: ${serviceUuid.toHexString()} != $_serviceUuid");
        return;
    }

    Uint8List payload = reader.readRemaining();
    if (isZstdCompressed) {
      payload = _decompressZstdIfNeeded(payload);
    }

    debugPrint("Notify Method: $methodId");

    if (methodId == _methodSyncToMeDeltaInfo) {
      _processSyncToMeDeltaInfo(payload);
    } else if (methodId == _methodSyncNearDeltaInfo) {
      _processSyncNearDeltaInfo(payload);
    }
  }

  void _processFrameDown(ByteReader reader, bool isZstdCompressed) {
    if (reader.remaining < 4) return;
    reader.readUInt32BE(); // serverSequenceId
    if (reader.remaining == 0) return;

    Uint8List nestedPacket = reader.readRemaining();
    if (isZstdCompressed) {
      nestedPacket = _decompressZstdIfNeeded(nestedPacket);
    }
    
    _parsePacketSequence(nestedPacket);
  }

  void _parsePacketSequence(Uint8List data) {
    final reader = ByteReader(data);
    while (reader.remaining > 0) {
      if (reader.remaining < 4) break;
      
      final packetSize = reader.peekUInt32BE();
      if (packetSize < 6 || packetSize > reader.remaining) break;

      final packetData = reader.readBytes(packetSize);
      _parseSinglePacket(packetData, packetSize);
    }
  }

  Uint8List _decompressZstdIfNeeded(Uint8List buffer) {
    if (buffer.length < 4) return buffer;
    try {
       // Note: es_compression might need the frame header check if we want to be robust
       // But for now, let's assume if the flag is set, it's Zstd.
       // The C# code handles skippable frames manually. 
       // es_compression's ZstdDecoder should handle standard frames.
       // return Uint8List.fromList(zstd.decode(buffer));
       return Uint8List.fromList(ZstdDecoder().convert(buffer));
    } catch (e) {
      debugPrint("Decompression failed: $e");
      return buffer;
    }
  }

  void _processSyncToMeDeltaInfo(Uint8List payload) {
    try {
      final msg = SyncToMeDeltaInfo.fromBuffer(payload);
      if (msg.hasDeltaInfo() && msg.deltaInfo.hasBaseDelta()) {
        _processAoiSyncDelta(msg.deltaInfo.baseDelta);
      }
    } catch (e) {
      debugPrint("Error parsing SyncToMeDeltaInfo: $e");
    }
  }

  void _processSyncNearDeltaInfo(Uint8List payload) {
    try {
      final msg = SyncNearDeltaInfo.fromBuffer(payload);
      for (final delta in msg.deltaInfos) {
        _processAoiSyncDelta(delta);
      }
    } catch (e) {
      debugPrint("Error parsing SyncNearDeltaInfo: $e");
    }
  }

  void _processAoiSyncDelta(AoiSyncDelta delta) {
    if (!delta.hasSkillEffects()) return;
    
    for (final damage in delta.skillEffects.damages) {
      int val = 0;
      if (damage.hasValue()) {
        val = damage.value.toInt();
      } else if (damage.hasLuckyValue()) {
         val = damage.luckyValue.toInt();
      }
      
      if (val != 0) {
        final isCrit = (damage.typeFlag & 1) == 1;
        final isHeal = damage.type == EDamageType.Heal;
        
        if (!isHeal) {
             debugPrint("Damage detected: $val (Crit: $isCrit)");
             onDamageDetected(val.abs(), isCrit);
        }
      }
    }
  }
}

class ByteReader {
  final Uint8List _data;
  int _offset = 0;
  final ByteData _view;

  ByteReader(this._data) : _view = ByteData.sublistView(_data);

  int get remaining => _data.length - _offset;

  int readUInt32BE() {
    final val = _view.getUint32(_offset, Endian.big);
    _offset += 4;
    return val;
  }

  int peekUInt32BE() {
    return _view.getUint32(_offset, Endian.big);
  }

  int readUInt16BE() {
    final val = _view.getUint16(_offset, Endian.big);
    _offset += 2;
    return val;
  }

  Int64 readUInt64BE() {
    final val = _view.getUint64(_offset, Endian.big);
    _offset += 8;
    return Int64(val);
  }

  Uint8List readBytes(int length) {
    final val = _data.sublist(_offset, _offset + length);
    _offset += length;
    return val;
  }

  Uint8List readRemaining() {
    final val = _data.sublist(_offset);
    _offset = _data.length;
    return val;
  }
}
