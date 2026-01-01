import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:zstd/zstd.dart';
import 'package:fixnum/fixnum.dart';

import '../state/data_storage.dart';
import '../tools/byte_reader.dart';
import 'message_handler_registry.dart';

class MessageAnalyzerV2 {
  final MessageHandlerRegistry _registry;
  final ZstdCodec _zstd = ZstdCodec();

  // Message Types
  static const int _msgTypeCall = 1;
  static const int _msgTypeNotify = 2;
  static const int _msgTypeReturn = 3;
  static const int _msgTypeFrameDown = 6;

  // Service UUID for Combat (0x0000000063335342)
  static final BigInt _combatServiceUuid = BigInt.parse("63335342", radix: 16);

  MessageAnalyzerV2(DataStorage storage) : _registry = MessageHandlerRegistry(storage);

  void process(Uint8List packetData) {
    if (packetData.isEmpty) return;

    final reader = ByteReader(packetData);
    if (reader.remaining < 2) return;

    final packetType = reader.readUInt16BE();
    final isZstdCompressed = (packetType & 0x8000) != 0;
    final msgTypeId = packetType & 0x7FFF;

    final payload = reader.readBytes(reader.remaining);

    switch (msgTypeId) {
      case _msgTypeCall:
        _processCallMsg(payload, isZstdCompressed);
        break;
      case _msgTypeNotify:
        _processNotifyMsg(payload, isZstdCompressed);
        break;
      case _msgTypeFrameDown:
        _processFrameDown(payload, isZstdCompressed);
        break;
      case _msgTypeReturn:
        // _processReturnMsg(payload, isZstdCompressed);
        break;
      default:
        // debugPrint("[BM] Unknown Message Type: $msgTypeId");
        break;
    }
  }

  void _processNotifyMsg(Uint8List data, bool isCompressed) {
    final reader = ByteReader(data);
    if (reader.remaining < 16) return; // 8 + 4 + 4

    final serviceUuid = reader.readUInt64BE();
    reader.skip(4); // stubId
    final methodId = reader.readUInt32BE();

    if (serviceUuid != _combatServiceUuid) {
      // debugPrint("[BM] Non-combat service: ${serviceUuid.toRadixString(16)}");
      return;
    }

    Uint8List msgPayload = reader.readBytes(reader.remaining);
    if (isCompressed) {
      try {
        msgPayload = Uint8List.fromList(_zstd.decode(msgPayload));
      } catch (e) {
        debugPrint("[BM] Zstd decompression failed: $e");
        return;
      }
    }

    final processor = _registry.getProcessor(methodId);
    if (processor != null) {
      // debugPrint("[BM] Processing method: $methodId");
      processor.process(msgPayload);
    } else {
      // debugPrint("[BM] No processor for method: $methodId");
    }
  }

  void _processCallMsg(Uint8List data, bool isCompressed) {
    // Call message structure is similar to Notify but might have different header?
    // Usually Call is Client -> Server.
    // If we are sniffing both ways, we might see Calls.
    // But usually we care about Server -> Client (Notify, Return, FrameDown).
    // C# implementation has ProcessCallMsg, let's assume it's similar or check C# code if needed.
    // For now, Notify is the main one for Sync messages.
  }

  void _processFrameDown(Uint8List data, bool isCompressed) {
    final reader = ByteReader(data);
    if (reader.remaining < 4) return;

    reader.skip(4); // serverSequenceId

    if (reader.remaining == 0) return;

    Uint8List innerPayload = reader.readBytes(reader.remaining);

    if (isCompressed) {
      try {
        innerPayload = Uint8List.fromList(_zstd.decode(innerPayload));
      } catch (e) {
        debugPrint("[BM] Zstd decompression failed in FrameDown: $e");
        return;
      }
    }
    
    _processPacketStream(innerPayload);
  }

  void _processPacketStream(Uint8List streamData) {
    var offset = 0;
    final view = ByteData.sublistView(streamData);
    
    while (offset + 4 <= streamData.length) {
      final packetSize = view.getUint32(offset, Endian.big);
      if (packetSize < 6) break;
      if (offset + packetSize > streamData.length) break;
      
      // Extract body (skip size 4 bytes)
      // packetSize includes the size header itself.
      // process() expects the body (Type + Payload).
      // So we pass streamData.sublist(offset + 4, offset + packetSize)
      
      final body = streamData.sublist(offset + 4, offset + packetSize);
      process(body);
      
      offset += packetSize;
    }
  }
}
