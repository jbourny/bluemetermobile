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
  // Method IDs
  static const int _methodSyncNearEntities = 0x00000006; // int = 6
  static const int _methodSyncContainerData = 0x00000015; // int = 21
  static const int _methodSyncContainerDirtyData = 0x00000016; // int = 22
  static const int _methodSyncToMeDeltaInfo = 0x0000002E; // int = 46
  static const int _methodSyncNearDeltaInfo = 0x0000002D; // int = 45
  static const int _serviceUuid = 0x63335342; // int = 1667330242

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
    debugPrint("[BM] Notify Method V2: $methodId");

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
    else{
      // try{
      //     debugPrint("[BM] Trying to parse unknown Notify Method: $methodId as SyncContainerData");
      //     final msg = SyncContainerData.fromBuffer(payload);
      //     if (msg.hasVData() && msg.vData.hasCharId()) {
      //       debugPrint("[BM] Successfully parsed SyncContainerData from Notify (MethodId=$methodId)");
      //       await _processSyncContainerData(payload);
      //       return;
      //     }
      //     else{
      //       debugPrint("[BM] Trying to parse unknown Notify Method: $methodId as SyncContainerDirtyData");
      //       final msg = SyncContainerDirtyData.fromBuffer(payload);
      //       if (msg.hasVData() && msg.vData.bufferS.isNotEmpty) {
      //         debugPrint("[BM] Successfully parsed SyncContainerDirtyData from Notify (MethodId=$methodId)");
      //         await _processSyncContainerDirtyData(payload);
      //         return;
      //       }
      //     }
      // }
      // catch(e){
      //   try{

      //   }
      //   catch(e){
      //     // ignore

      //   }

      //   // ignore
      // }
      debugPrint("[BM] Unknown Notify Method: $methodId");
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

        if (msg.vData.hasRoleLevel()) {
           info.level = msg.vData.roleLevel.level;
           changed = true;
        }
        
        if (msg.vData.hasAttr()) {
           if (msg.vData.attr.hasCurHp()) {
             info.hp = msg.vData.attr.curHp;
             changed = true;
           }
           if (msg.vData.attr.hasMaxHp()) {
             info.maxHp = msg.vData.attr.maxHp;
             changed = true;
           }
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
        } else if (fieldIndex == 16) {
           // HP
           if (!_doesStreamHaveIdentifier(reader)) {
             debugPrint("[BM] DirtyData inner stream missing identifier (HP)");
             return;
           }
           
           final innerFieldIndex = reader.readUInt32LE();
           reader.readInt32LE(); // Skip
           
           final storageUid = playerUid >> 16;
           final info = (await storage.getPlayerInfo(storageUid)) ?? PlayerInfo(uid: storageUid);
           bool changed = false;

           if (innerFieldIndex == 1) {
             // CurHP
             final curHp = reader.readUInt32LE();
             info.hp = Int64(curHp);
             changed = true;
             debugPrint("[BM] Updated MY CurHP from DirtyData: $curHp");
           } else if (innerFieldIndex == 2) {
             // MaxHP
             final maxHp = reader.readUInt32LE();
             info.maxHp = Int64(maxHp);
             changed = true;
             debugPrint("[BM] Updated MY MaxHP from DirtyData: $maxHp");
           }
           
           if (changed) {
             storage.updatePlayerInfo(info);
           }
        } else if (fieldIndex == 61) {
           // Profession
           if (!_doesStreamHaveIdentifier(reader)) {
             debugPrint("[BM] DirtyData inner stream missing identifier (Profession)");
             return;
           }
           
           final innerFieldIndex = reader.readUInt32LE();
           reader.readInt32LE(); // Skip
           
           if (innerFieldIndex == 1) {
             final curProfessionId = reader.readUInt32LE();
             reader.readInt32LE(); // Skip
             
             if (curProfessionId != 0) {
               final storageUid = playerUid >> 16;
               final info = (await storage.getPlayerInfo(storageUid)) ?? PlayerInfo(uid: storageUid);
               info.professionId = curProfessionId;
               storage.updatePlayerInfo(info);
               debugPrint("[BM] Updated MY Profession from DirtyData: $curProfessionId");
             }
           }
        } else {
           debugPrint("[BM] DirtyData FieldIndex $fieldIndex ignored");
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
        // debugPrint("[BM] Entity Type: ${entity.entType.value} UUID: ${entity.uuid}");
        if (entity.entType != EEntityType.entChar) continue;

        final playerUid = entity.uuid >> 16; // ShiftRight16
        if (playerUid == Int64.ZERO) continue;

        if (entity.hasAttrs()) {
          await _processPlayerAttrs(playerUid, entity.attrs.attrs);
        }
      }
    } catch (e) {
      debugPrint("[BM] Error parsing SyncNearEntities: $e");
    }
  }

  Future<void> _processPlayerAttrs(Int64 playerUid, List<Attr> attrs) async {
    final storage = DataStorage();
    PlayerInfo info =
        (await storage.getPlayerInfo(playerUid)) ?? PlayerInfo(uid: playerUid);

    bool changed = false;
    
    debugPrint("[BM] Processing attrs for $playerUid. Count: ${attrs.length}");

    for (final attr in attrs) {
      if (!attr.hasId() || !attr.hasRawData()) continue;

      final attrType = AttrType.fromValue(attr.id);
      if (attrType == null) {
        // On affiche l'ID, la taille et les données brutes pour le debug
         debugPrint("[BM] Unknown Attr ID: ${attr.id} Len: ${attr.rawData.length} : ${CodedBufferReader(attr.rawData).readString()}");
         continue;
      }

      try {
        switch (attrType) {
          case AttrType.attrName:
            try {
              info.name = CodedBufferReader(attr.rawData).readString();
              changed = true;
              debugPrint("[BM] Got Name for $playerUid: ${info.name}");
            } catch (e) {
               debugPrint("[BM] Failed to parse Name: $e");
            }
            break;
          case AttrType.attrProfessionId:
            info.professionId = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            debugPrint("[BM] Got Profession for $playerUid: ${info.professionId}");
            break;
          case AttrType.attrFightPoint:
            info.combatPower = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.attrLevel:
            info.level = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.attrRankLevel:
            info.rankLevel = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.attrCri:
            info.critical = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.attrLucky:
            info.lucky = CodedBufferReader(attr.rawData).readInt32();
            changed = true;
            break;
          case AttrType.attrHp:
            info.hp = Int64(CodedBufferReader(attr.rawData).readInt32());
            changed = true;
            break;
          case AttrType.attrMaxHp:
            info.maxHp = Int64(CodedBufferReader(attr.rawData).readInt32());
            changed = true;
            debugPrint("[BM] Updated MY MaxHP from DirtyData: ${info.maxHp}");
            break;
          case AttrType.attrUnknown50:
             // Just log it for now
             debugPrint("[BM] Got Attr 50 (Len: ${attr.rawData.length})");
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

      if (msg.hasDeltaInfo()) {
        final storage = DataStorage();
        Int64 currentUuid = Int64.ZERO;
        
        // 1. Determine UUID from the packet
        if (msg.deltaInfo.hasUuid()) {
           currentUuid = msg.deltaInfo.uuid;
        } else if (msg.deltaInfo.hasBaseDelta() && msg.deltaInfo.baseDelta.hasUuid()) {
           currentUuid = msg.deltaInfo.baseDelta.uuid;
        }

        // 2. Update Storage UUID and PlayerInfo if we found a valid UUID
        if (currentUuid != Int64.ZERO) {
           if (storage.currentPlayerUuid != currentUuid) {
             storage.currentPlayerUuid = currentUuid;
             debugPrint("[BM] Updated CurrentPlayerUUID: $currentUuid");
           }
           
           // 3. Ensure PlayerInfo exists and has a name (fallback to "Moi")
           final shortUuid = currentUuid >> 16;
           PlayerInfo? info = await storage.getPlayerInfo(shortUuid);
           
           if (info == null || (info.name == null || info.name!.isEmpty)) {
              info ??= PlayerInfo(uid: shortUuid);
              info.name = "Moi";
              storage.updatePlayerInfo(info);
              debugPrint("[BM] Set default name 'Moi' for current player ($shortUuid)");
           }
        }

        if (msg.deltaInfo.hasBaseDelta()) {
          // debugPrint("[BM] SyncToMeDeltaInfo has BaseDelta. HasAttrs: ${msg.deltaInfo.baseDelta.hasAttrs()} UUID: ${msg.deltaInfo.baseDelta.uuid}");
          
          // Fix: If baseDelta has attributes but (no UUID OR UUID is 0), use the UUID from deltaInfo (or storage)
          // This is common in SyncToMeDeltaInfo where the UUID is in the parent message
          bool needsUuidInjection = msg.deltaInfo.baseDelta.hasAttrs() && 
                                    (!msg.deltaInfo.baseDelta.hasUuid() || msg.deltaInfo.baseDelta.uuid == Int64.ZERO);

          if (needsUuidInjection) {
             Int64 targetUuid = Int64.ZERO;
             if (currentUuid != Int64.ZERO) {
               targetUuid = currentUuid;
             } else {
               targetUuid = storage.currentPlayerUuid;
             }
             
             if (targetUuid != Int64.ZERO) {
               // debugPrint("[BM] Processing attributes for ME (UUID: $targetUuid) from SyncToMeDeltaInfo (Injection)");
               await _processPlayerAttrs(targetUuid >> 16, msg.deltaInfo.baseDelta.attrs.attrs);
             }
          }

          await _processAoiSyncDelta(msg.deltaInfo.baseDelta);
        }
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
      
      // debugPrint("[BM] AoiSyncDelta UUID: $targetUuidRaw Suffix: $targetSuffix HasAttrs: ${delta.hasAttrs()}");

      if (delta.hasAttrs()) {
        // Check if target is player (IsUuidPlayerRaw logic from C#)
        // C# IsUuidPlayerRaw: (uuid & 0xFFFF) == 640
        // But logs show UUID ending in 0x640 (1600), so we accept both.
        if (targetSuffix == 640 || targetSuffix == 1600) {
          debugPrint("[BM] Target is player ($targetUuid). Processing attrs...");
          
          // Debug: Print raw bytes of attrs if empty
          if (delta.attrs.attrs.isEmpty) {
             debugPrint("[BM] Attrs list is empty. Checking MapAttrs...");
             // Check if mapAttrs has anything (just in case)
             if (delta.attrs.mapAttrs.isNotEmpty) {
                debugPrint("[BM] MapAttrs has ${delta.attrs.mapAttrs.length} items.");
             }
          }
          
          await _processPlayerAttrs(targetUuid, delta.attrs.attrs);
        } else {
          debugPrint("[BM] Target is NOT player ($targetUuid). Suffix: $targetSuffix");
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
          final isHeal = damage.type == EDamageType.heal;
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
