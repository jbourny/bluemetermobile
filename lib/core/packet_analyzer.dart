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
      _parseSinglePacket(packetData, packetSize);
    }
  }

  void _parseSinglePacket(Uint8List packetData, int expectedSize) {
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

    debugPrint(
      "Parsed packet: Type=$msgTypeId, Compressed=$isZstdCompressed, Size=$expectedSize",
    );

    if (msgTypeId == 2) {
      // Notify
      _processNotifyMsg(packetReader, isZstdCompressed);
    } else if (msgTypeId == 6) {
      // FrameDown
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
    } else if (methodId == _methodSyncNearEntities) {
      _processSyncNearEntities(payload);
    } else if (methodId == _methodSyncContainerData) {
      _processSyncContainerData(payload);
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

  void _processSyncContainerData(Uint8List payload) {
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

        PlayerInfo info =
            storage.getPlayerInfo(playerUid) ?? PlayerInfo(uid: playerUid);
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
          debugPrint("Updated MY player info: $info");
        }
      }
    } catch (e) {
      debugPrint("Error parsing SyncContainerData: $e");
    }
  }

  void _processSyncNearEntities(Uint8List payload) {
    try {
      final msg = SyncNearEntities.fromBuffer(payload);
      for (final entity in msg.appear) {
        if (entity.entType != EEntityType.EntChar) continue;

        final playerUid = entity.uuid >> 16; // ShiftRight16
        if (playerUid == Int64.ZERO) continue;

        if (entity.hasAttrs()) {
          _processPlayerAttrs(playerUid, entity.attrs.attrs);
        }
      }
    } catch (e) {
      debugPrint("Error parsing SyncNearEntities: $e");
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

  void _processPlayerAttrs(Int64 playerUid, List<Attr> attrs) {
    final storage = DataStorage();
    PlayerInfo info =
        storage.getPlayerInfo(playerUid) ?? PlayerInfo(uid: playerUid);

    bool changed = false;
    
    // Debug: Print all received attributes
    final attrIds = attrs.map((a) => a.id).toList();
    debugPrint("Processing attrs for $playerUid: $attrIds");

    for (final attr in attrs) {
      if (!attr.hasId() || !attr.hasRawData()) continue;

      final reader = CodedBufferReader(attr.rawData);
      final attrType = AttrType.fromValue(attr.id);

      if (attrType == null) {
        // Debug unknown attr
        // debugPrint("Unknown Attr ID: ${attr.id}");
        continue;
      }

      try {
        switch (attrType) {
          case AttrType.AttrName:
            String? parsedName;
            
            // Debug raw bytes
            final hex = attr.rawData.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
            debugPrint("Attr Name ID=${attr.id} Raw: $hex");

            // 1. Try Custom String Format
            parsedName = _tryParseCustomString(Uint8List.fromList(attr.rawData));

            // 2. Try Protobuf String
            if (parsedName == null) {
              try {
                parsedName = reader.readString();
              } catch (_) {}
            }

            // 3. Try Raw UTF-8
            if (parsedName == null) {
              try {
                parsedName = utf8.decode(attr.rawData);
              } catch (_) {}
            }

            if (parsedName != null && parsedName.isNotEmpty) {
              info.name = parsedName;
              debugPrint("Parsed Name for $playerUid: $parsedName");
              changed = true;
            }
            break;
          case AttrType.AttrProfessionId:
            info.professionId = reader.readInt32();
            changed = true;
            break;
          case AttrType.AttrFightPoint:
            info.combatPower = reader.readInt32();
            changed = true;
            break;
          case AttrType.AttrLevel:
            info.level = reader.readInt32();
            changed = true;
            break;
          case AttrType.AttrRankLevel:
            info.rankLevel = reader.readInt32();
            changed = true;
            break;
          case AttrType.AttrCri:
            info.critical = reader.readInt32();
            changed = true;
            break;
          case AttrType.AttrLucky:
            info.lucky = reader.readInt32();
            changed = true;
            break;
          case AttrType.AttrHp:
            info.hp = Int64(reader.readInt32());
            changed = true;
            break;
          case AttrType.AttrMaxHp:
            info.maxHp = Int64(reader.readInt32());
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
    if (delta.hasUuid()) {
      // Check for attributes update in delta
      if (delta.hasAttrs()) {
        final targetUuidRaw = delta.uuid;
        // Check if target is player (IsUuidPlayerRaw logic from C#)
        // C# IsUuidPlayerRaw: (uuid & 0xFFFF) == 640
        if ((targetUuidRaw.toInt() & 0xFFFF) == 640) {
          final targetUuid = targetUuidRaw >> 16;
          _processPlayerAttrs(targetUuid, delta.attrs.attrs);
        }
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

        if (!isHeal) {
          // debugPrint("Damage detected: $val (Crit: $isCrit) from $attackerUuid");
          onDamageDetected(val.abs(), isCrit);

          // Update DataStorage
          DataStorage().addDamage(
            attackerUuid,
            Int64(val.abs()),
            DateTime.now().microsecondsSinceEpoch * 10,
          ); // Approx ticks
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
