import 'dart:typed_data';
import 'dart:convert';
// import 'package:es_compression/zstd.dart';
import 'package:zstd/zstd.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:protobuf/protobuf.dart';
import 'protocol/blue_protocol.dart';
import 'models/attr_type.dart';
import 'models/player_info.dart';
import 'state/data_storage.dart';

class PacketAnalyzer {
  static const int _zstdMagic = 0xFD2FB528;
  static const int _skippableMagicMin = 0x184D2A50;
  static const int _skippableMagicMax = 0x184D2A5F;

  // Method IDs
  static const int _methodSyncNearEntities = 0x00000006;
  static const int _methodSyncContainerData = 0x00000015;
  static const int _methodSyncContainerDirtyData = 0x00000016;
  static const int _methodSyncToMeDeltaInfo = 0x0000002E;
  static const int _methodSyncNearDeltaInfo = 0x0000002D;
  static const int _serviceUuid = 0x63335342; // 0x0000000063335342

  final Function(int damage, bool isCrit) onDamageDetected;
  final BytesBuilder _buffer = BytesBuilder();

  PacketAnalyzer({required this.onDamageDetected});

  Future<void> processPacket(Uint8List chunk) async {
    _buffer.add(chunk);

    while (true) {
      final bytes = _buffer.toBytes();
      if (bytes.length < 4) break; // Need at least size header

      // Peek packet size (first 4 bytes)
      final packetSize = ByteData.sublistView(
        bytes,
        0,
        4,
      ).getUint32(0, Endian.big);

      // Check for handshake signature (00 63 33 53) which is 6499155
      // This prevents the analyzer from waiting for a 6.5MB packet that never comes
      if (packetSize == 0x00633353) {
        debugPrint("Handshake detected (00 63 33 53), skipping 6 bytes...");
        if (bytes.length >= 6) {
          final remaining = bytes.sublist(6);
          _buffer.clear();
          _buffer.add(remaining);
          continue;
        } else {
          // Wait for more data to skip
          break;
        }
      }

      if (packetSize < 4 || packetSize > 10000000) {
        debugPrint(
          "Invalid packet size: $packetSize. Buffer len: ${bytes.length}. Clearing buffer.",
        );
        _buffer.clear();
        break;
      }

      // Check if we have the full packet (packetSize includes the header itself)
      if (bytes.length < packetSize) {
        debugPrint(
          "Waiting for more data. Have: ${bytes.length}, Need: $packetSize",
        );
        break; // Wait for more data
      }

      // Extract the full packet
      final packetData = bytes.sublist(0, packetSize);

      // Remove processed bytes from buffer
      final remaining = bytes.sublist(packetSize);
      _buffer.clear();
      _buffer.add(remaining);

      // Process the extracted packet body
      await _parseSinglePacket(packetData, packetSize);
    }
  }

  Future<void> _parseSinglePacket(Uint8List packetData, int expectedSize) async {
    final packetReader = ByteReader(packetData);
    if (packetReader.remaining < 4) return;

    final sizeAgain = packetReader.readUInt32BE();
    if (sizeAgain != expectedSize) {
      debugPrint("Packet size mismatch: $sizeAgain != $expectedSize");
      final dump = packetData
          .take(8)
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      debugPrint("Packet dump: $dump");
      return;
    }

    if (packetReader.remaining < 2) return;
    final packetType = packetReader.readUInt16BE();
    final isZstdCompressed = (packetType & 0x8000) != 0;
    final msgTypeId = packetType & 0x7FFF;

    // debugPrint(
    //   "Parsed packet: Type=$msgTypeId, Compressed=$isZstdCompressed, Size=$expectedSize",
    // );
    if (msgTypeId == 2 || msgTypeId == 3) {
       debugPrint("[BM] Packet: Type=$msgTypeId Size=$expectedSize");
    }

    if (msgTypeId == 2) {
      // Notify
      await _processNotifyMsg(packetReader, isZstdCompressed);
    } else if (msgTypeId == 3) {
      // Response
      await _processResponseMsg(packetReader, isZstdCompressed);
    } else if (msgTypeId == 6) {
      // FrameDown
      await _processFrameDown(packetReader, isZstdCompressed);
    }
  }

  Future<void> _processResponseMsg(ByteReader reader, bool isZstdCompressed) async {
    // Type 3 (Return) messages only have a 4-byte StubId header
    if (reader.remaining < 4) return;

    final stubId = reader.readUInt32BE();
    debugPrint("[BM] Return Msg: StubId=$stubId Size=${reader.remaining}");

    Uint8List payload = reader.readRemaining();
    if (isZstdCompressed) {
      payload = _decompressZstdIfNeeded(payload);
    }

    // Attempt to parse as SyncContainerData (blindly, since we don't track StubId)
    try {
      final msg = SyncContainerData.fromBuffer(payload);
      if (msg.hasVData() && msg.vData.hasCharId()) {
        debugPrint("[BM] Successfully parsed SyncContainerData from Return (StubId=$stubId)");
        await _processSyncContainerData(payload);
      } else {
         // debugPrint("[BM] Return Msg (StubId=$stubId) is not SyncContainerData");
      }
    } catch (e) {
      // debugPrint("[BM] Failed to parse Return Msg as SyncContainerData: $e");
    }
  }

  Future<void> _dispatchMethod(int methodId, Uint8List payload) async {
    if (methodId == _methodSyncContainerData) {
      await _processSyncContainerData(payload);
    } else if (methodId == _methodSyncNearEntities) {
      await _processSyncNearEntities(payload);
    }
  }

  Future<void> _processNotifyMsg(ByteReader reader, bool isZstdCompressed) async {
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

    // debugPrint("Notify Method: $methodId");
    debugPrint("[BM] Notify Method: $methodId");

    if (methodId == _methodSyncToMeDeltaInfo) {
      await _processSyncToMeDeltaInfo(payload);
    } else if (methodId == _methodSyncNearDeltaInfo) {
      await _processSyncNearDeltaInfo(payload);
    } else if (methodId == _methodSyncNearEntities) {
      await _processSyncNearEntities(payload);
    } else if (methodId == _methodSyncContainerData) {
      await _processSyncContainerData(payload);
    } else if (methodId == _methodSyncContainerDirtyData) {
      await _processSyncContainerDirtyData(payload);
    }
  }

  Future<void> _processFrameDown(ByteReader reader, bool isZstdCompressed) async {
    if (reader.remaining < 4) return;
    reader.readUInt32BE(); // serverSequenceId
    if (reader.remaining == 0) return;

    Uint8List nestedPacket = reader.readRemaining();
    if (isZstdCompressed) {
      nestedPacket = _decompressZstdIfNeeded(nestedPacket);
    }

    await _parsePacketSequence(nestedPacket);
  }

  Future<void> _parsePacketSequence(Uint8List data) async {
    final reader = ByteReader(data);
    while (reader.remaining > 0) {
      if (reader.remaining < 4) break;

      final packetSize = reader.peekUInt32BE();
      if (packetSize < 6 || packetSize > reader.remaining) break;

      final packetData = reader.readBytes(packetSize);
      await _parseSinglePacket(packetData, packetSize);
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

  Future<void> _processSyncContainerData(Uint8List payload) async {
    debugPrint("[BM] Processing SyncContainerData (Len: ${payload.length})");
    try {
      // We need SyncContainerData definition in protocol
      // But for now let's try to parse what we can or add it to protocol
      // Assuming SyncContainerData is added to protocol.dart
      final msg = SyncContainerData.fromBuffer(payload);
      if (msg.hasVData() && msg.vData.hasCharId()) {
        final playerUid = msg.vData.charId;
        final storage = DataStorage();

        // Update current player UUID
        storage.currentPlayerUuid = playerUid;
        
        // Shift right 16 for storage key
        final storageUid = playerUid >> 16;

        PlayerInfo info =
            (await storage.getPlayerInfo(storageUid)) ?? PlayerInfo(uid: storageUid);
        bool changed = false;

        if (msg.vData.hasCharBase()) {
          if (msg.vData.charBase.hasName()) {
            info.name = msg.vData.charBase.name;
            changed = true;
          }
          if (msg.vData.charBase.hasFightPoint()) {
            info.combatPower = msg.vData.charBase.fightPoint;
            changed = true;
          }
        }

        if (msg.vData.hasProfessionList() &&
            msg.vData.professionList.hasCurProfessionId()) {
          info.professionId = msg.vData.professionList.curProfessionId;
          changed = true;
        }

        if (changed) {
          storage.updatePlayerInfo(info);
          debugPrint("[BM] Updated MY player info: $info");
        }
      }
    } catch (e) {
      debugPrint("[BM] Error parsing SyncContainerData: $e");
    }
  }

  bool _doesStreamHaveIdentifier(ByteReader reader) {
    if (reader.remaining < 8) return false;
    final id1 = reader.readUInt32LE();
    reader.readInt32LE(); // guard

    if (id1 != 0xFFFFFFFE) return false;

    if (reader.remaining < 8) return false;
    reader.readInt32LE(); // 0xFFFFFFFD
    reader.readInt32LE(); // guard

    return true;
  }

  Future<void> _processSyncContainerDirtyData(Uint8List payload) async {
    debugPrint("[BM] Processing SyncContainerDirtyData (Len: ${payload.length})");
    try {
      final msg = SyncContainerDirtyData.fromBuffer(payload);
      if (msg.hasVData() && msg.vData.bufferS.isNotEmpty) {
        final buffer = Uint8List.fromList(msg.vData.bufferS);
        final reader = ByteReader(buffer);

        if (!_doesStreamHaveIdentifier(reader)) {
          debugPrint("[BM] DirtyData stream missing identifier");
          return;
        }

        final fieldIndex = reader.readUInt32LE();
        reader.readInt32LE(); // Skip
        
        debugPrint("[BM] DirtyData FieldIndex: $fieldIndex");

        final storage = DataStorage();
        var playerUid = storage.currentPlayerUuid;
        
        if (playerUid == Int64.ZERO) {
           debugPrint("[BM] Warning: Received SyncContainerDirtyData but CurrentPlayerUUID is 0. Ignoring.");
           // Try to use the persisted UUID if available (it might be loaded async, but let's check)
           // Actually DataStorage loads it in constructor, but it's async.
           // If it's still 0, we can't do much.
           // return; // Don't return, let's see if we can parse it anyway for debugging
        }

        if (fieldIndex == 2) {
           if (!_doesStreamHaveIdentifier(reader)) {
             debugPrint("[BM] DirtyData inner stream missing identifier");
             return;
           }
           
           final innerFieldIndex = reader.readUInt32LE();
           reader.readInt32LE(); // Skip
           
           debugPrint("[BM] DirtyData InnerFieldIndex: $innerFieldIndex");

           if (innerFieldIndex == 5) {
             // Name
             final name = reader.readString();
             if (name.isNotEmpty) {
                // Shift right 16 to get the actual UID key for storage
                // The C# code does: var playerUid = DataStorage.CurrentPlayerUUID.ShiftRight16();
                // In Dart, Int64 shift right is >>
                final storageUid = playerUid >> 16;
                
                final info = (await storage.getPlayerInfo(storageUid)) ?? PlayerInfo(uid: storageUid);
                info.name = name;
                storage.updatePlayerInfo(info);
                debugPrint("[BM] Updated MY player name from DirtyData: $name (UID: $storageUid)");
             }
           } else if (innerFieldIndex == 35) {
             // Combat Power
             final cp = reader.readInt32LE();
             final storageUid = playerUid >> 16;
             final info = (await storage.getPlayerInfo(storageUid)) ?? PlayerInfo(uid: storageUid);
             info.combatPower = cp;
             storage.updatePlayerInfo(info);
             debugPrint("[BM] Updated MY CP from DirtyData: $cp");
           }
        } else {
           debugPrint("[BM] DirtyData FieldIndex $fieldIndex ignored (Not 2)");
        }
      }
    } catch (e) {
      debugPrint("[BM] Error parsing SyncContainerDirtyData: $e");
    }
  }

  Future<void> _processSyncNearEntities(Uint8List payload) async {
    try {
      final msg = SyncNearEntities.fromBuffer(payload);
      debugPrint("[BM] SyncNearEntities: ${msg.appear.length} entities");
      for (final entity in msg.appear) {
        debugPrint("[BM] Entity Type: ${entity.entType.value} UUID: ${entity.uuid}");
        if (entity.entType != EEntityType.EntChar) continue;

        final playerUid = entity.uuid >> 16; // ShiftRight16
        if (playerUid == Int64.ZERO) continue;

        if (entity.hasAttrs()) {
          await _processPlayerAttrs(playerUid, entity.attrs.attrs);
        } else {
           debugPrint("[BM] Entity $playerUid has no attrs");
        }
      }
    } catch (e) {
      debugPrint("[BM] Error parsing SyncNearEntities: $e");
    }
  }

  String? _tryParseCustomString(Uint8List data) {
    if (data.length < 8) return null;
    final view = ByteData.sublistView(data);
    final length = view.getUint32(0, Endian.little);

    // Check bounds
    if (length > data.length - 8) return null;

    try {
      final bytes = data.sublist(8, 8 + length);
      return utf8.decode(bytes);
    } catch (e) {
      return null;
    }
  }

  Future<void> _processPlayerAttrs(Int64 playerUid, List<Attr> attrs) async {
    final storage = DataStorage();
    PlayerInfo info =
        (await storage.getPlayerInfo(playerUid)) ?? PlayerInfo(uid: playerUid);

    bool changed = false;
    
    // Debug: Print all received attributes
    final attrIds = attrs.map((a) => a.id).toList();
    debugPrint("Processing attrs for $playerUid: $attrIds");

    for (final attr in attrs) {
      if (!attr.hasId() || !attr.hasRawData()) continue;

      // Dump raw data for ALL attributes to find the name
      final hex = attr.rawData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
      if (attr.rawData.length > 0) {
         // Try to decode as string to see if it looks like text
         String asText = "";
         try {
           asText = utf8.decode(attr.rawData, allowMalformed: true);
           // Remove control chars for display
           asText = asText.replaceAll(RegExp(r'[\x00-\x1F]'), '.');
         } catch (_) {}
         debugPrint("[BM] Attr ID=${attr.id} Len=${attr.rawData.length} Hex=$hex Text=$asText");
      }

      final reader = CodedBufferReader(attr.rawData);
      final attrType = AttrType.fromValue(attr.id);

      if (attrType == null) {
        // Debug unknown attr
        // debugPrint("Unknown Attr ID: ${attr.id}");
        continue;
      }

      // Explicitly log when we find AttrName (ID 1)
      if (attrType == AttrType.AttrName) {
         debugPrint("[BM] Found AttrName (ID 1). RawData Len: ${attr.rawData.length}");
      }

      try {
        switch (attrType) {
          case AttrType.AttrName:
            // Debug raw bytes
            // final hex = attr.rawData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            // debugPrint("[BM] Attr Name ID=${attr.id} Raw: $hex");

            String? parsedName;

            // 1. Try Protobuf String (Varint Length + Bytes)
            try {
              final r = CodedBufferReader(attr.rawData);
              parsedName = r.readString();
            } catch (e) {
               debugPrint("[BM] Failed to readString for Name: $e");
            }

            // 2. Try Custom String Format (4-byte length prefix)
            if (parsedName == null || parsedName.isEmpty) {
               parsedName = _tryParseCustomString(Uint8List.fromList(attr.rawData));
            }

            // 3. Try Raw UTF-8 (fallback)
            if (parsedName == null || parsedName.isEmpty) {
              try {
                parsedName = utf8.decode(attr.rawData);
              } catch (_) {}
            }

            if (parsedName != null && parsedName.isNotEmpty) {
              // Filter out control characters if it looks like garbage
              // But allow some if it's just a prefix we missed
              // The logs showed names starting with . (06) which is length.
              // readString() consumes the length.
              
              info.name = parsedName;
              debugPrint("[BM] Parsed Name for $playerUid: $parsedName");
              changed = true;
            } else {
               debugPrint("[BM] Name parsing failed for ID 1. Raw: $hex");
            }
            break;
          case AttrType.AttrProfessionId:
            // Create new reader for each field to avoid position issues
            info.professionId = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.AttrFightPoint:
            info.combatPower = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.AttrLevel:
            info.level = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.AttrRankLevel:
            info.rankLevel = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.AttrCri:
            info.critical = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.AttrLucky:
            info.lucky = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.AttrHp:
            info.hp = Int64(CodedBufferReader(attr.rawData).readInt32());
            changed = true;
            break;
          case AttrType.AttrMaxHp:
            info.maxHp = Int64(CodedBufferReader(attr.rawData).readInt32());
            changed = true;
            break;
          default:
            break;
        }
      } catch (e) {
        debugPrint("Error parsing attr ${attrType.name}: $e");
      }
    }

    if (changed) {
      storage.updatePlayerInfo(info);
    }
  }

  Future<void> _processSyncToMeDeltaInfo(Uint8List payload) async {
    try {
      final msg = SyncToMeDeltaInfo.fromBuffer(payload);

      // Update CurrentPlayerUUID if available
      if (msg.hasDeltaInfo() && msg.deltaInfo.hasBaseDelta()) {
        final uuid = msg.deltaInfo.baseDelta.uuid;
        final storage = DataStorage();
        if (uuid != Int64.ZERO && storage.currentPlayerUuid != uuid) {
          storage.currentPlayerUuid = uuid;
          debugPrint("[BM] Updated CurrentPlayerUUID from SyncToMeDeltaInfo: $uuid");
        }
        await _processAoiSyncDelta(msg.deltaInfo.baseDelta);
      }
    } catch (e) {
      debugPrint("Error parsing SyncToMeDeltaInfo: $e");
    }
  }

  Future<void> _processSyncNearDeltaInfo(Uint8List payload) async {
    try {
      final msg = SyncNearDeltaInfo.fromBuffer(payload);
      for (final delta in msg.deltaInfos) {
        await _processAoiSyncDelta(delta);
      }
    } catch (e) {
      debugPrint("Error parsing SyncNearDeltaInfo: $e");
    }
  }

  Future<void> _processAoiSyncDelta(AoiSyncDelta delta) async {
    if (delta.hasUuid()) {
      // Check for attributes update in delta
      final targetUuidRaw = delta.uuid;
      final targetSuffix = targetUuidRaw.toInt() & 0xFFFF;
      final targetUuid = targetUuidRaw >> 16;

      if (delta.hasAttrs()) {
        // Check if target is player (IsUuidPlayerRaw logic from C#)
        // C# IsUuidPlayerRaw: (uuid & 0xFFFF) == 640
        // But logs show UUID ending in 0x640 (1600), so we accept both.
        if (targetSuffix == 640 || targetSuffix == 1600) {
          await _processPlayerAttrs(targetUuid, delta.attrs.attrs);
        }
      }
    

      if (!delta.hasSkillEffects()) return;

      for (final damage in delta.skillEffects.damages) {
        final attackerRaw = damage.topSummonerId != Int64.ZERO
            ? damage.topSummonerId
            : damage.attackerUuid;
        if (attackerRaw == Int64.ZERO) continue;

        final attackerUuid = attackerRaw >> 16;

        int val = 0;
        if (damage.hasValue()) {
          val = damage.value.toInt();
        } else if (damage.hasLuckyValue()) {
          val = damage.luckyValue.toInt();
        }

        if (val != 0) {
          final isCrit = (damage.typeFlag & 1) == 1;
          final isHeal = damage.type == EDamageType.Heal;
          final tick = DateTime.now().microsecondsSinceEpoch * 10;

          if (!isHeal) {
            // debugPrint("Damage detected: $val (Crit: $isCrit) from $attackerUuid");
            onDamageDetected(val.abs(), isCrit);

            // Update DataStorage
            DataStorage().addDamage(
              attackerUuid,
              targetUuid,
              Int64(val.abs()),
              tick,
            ); 
          } else {
             // Handle Heal
             DataStorage().addHeal(
               attackerUuid,
               targetUuid,
               Int64(val.abs()),
               tick,
             );
          }
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

  int readUInt32LE() {
    final val = _view.getUint32(_offset, Endian.little);
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

  int readInt32LE() {
    final val = _view.getInt32(_offset, Endian.little);
    _offset += 4;
    return val;
  }

  String readString() {
    if (remaining < 8) return "";

    final length = _view.getUint32(_offset, Endian.little);
    _offset += 4;

    _offset += 4; // Skip guard

    if (remaining < length) return "";

    String str = "";
    if (length > 0) {
      final bytes = _data.sublist(_offset, _offset + length);
      try {
        str = utf8.decode(bytes);
      } catch (e) {
        // ignore
      }
      _offset += length;
    }

    if (remaining >= 4) {
      _offset += 4; // Skip trailing guard
    }

    return str;
  }
}
