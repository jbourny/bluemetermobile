import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:protobuf/protobuf.dart';

import '../../protocol/blue_protocol.dart';
import '../../models/attr_type.dart';
import '../../state/data_storage.dart';
import '../../tools/byte_reader.dart';
import 'message_processor.dart';

class SyncNearEntitiesProcessor implements IMessageProcessor {
  final DataStorage _storage;

  SyncNearEntitiesProcessor(this._storage);

  @override
  void process(Uint8List payload) {
    try {
      final syncNearEntities = SyncNearEntities.fromBuffer(payload);
      if (syncNearEntities.appear.isEmpty) return;

      for (var entity in syncNearEntities.appear) {
        if (entity.entType != EEntityType.entChar) continue;

        final playerUid = entity.uuid >> 16;
        if (playerUid == Int64.ZERO) continue;

        final attrCollection = entity.attrs;
        if (attrCollection.attrs.isEmpty) continue;

        _processPlayerAttrs(playerUid, attrCollection.attrs);
      }
    } catch (e) {
      debugPrint("Error processing SyncNearEntities: $e");
    }
  }

  void _processPlayerAttrs(Int64 playerUid, List<Attr> attrs) {
    _storage.ensurePlayer(playerUid);

    for (var attr in attrs) {
      if (attr.id == 0 || attr.rawData.isEmpty) continue;
      
      // Attr rawData is a serialized value, we need to read it.
      // In C# it uses CodedInputStream. In Dart we can use ByteReader or CodedBufferReader.
      // Since rawData is just bytes, and we know the type based on ID.
      // Most are int32 or string.
      
      final reader = CodedBufferReader(attr.rawData);
      
      // Note: CodedBufferReader.readString() / readInt32() might expect tag? 
      // No, in C# `reader.ReadString()` reads a length-prefixed string.
      // `reader.ReadInt32()` reads a varint.
      // Protobuf's CodedInputStream in C# reads values directly if initialized with the array.
      
      final attrType = AttrType.fromId(attr.id);
      if (attrType == AttrType.unknown) continue;

      switch (attrType) {
        case AttrType.attrName:
          _storage.setPlayerName(playerUid, reader.readString());
          break;
        case AttrType.attrProfessionId:
          _storage.setPlayerProfessionId(playerUid, reader.readInt32());
          break;
        case AttrType.attrFightPoint:
          _storage.setPlayerCombatPower(playerUid, reader.readInt32());
          break;
        case AttrType.attrLevel:
          _storage.setPlayerLevel(playerUid, reader.readInt32());
          break;
        case AttrType.attrRankLevel:
          // _storage.setPlayerRankLevel(playerUid, reader.readInt32());
          break;
        case AttrType.attrCri:
          // _storage.setPlayerCritical(playerUid, reader.readInt32());
          break;
        case AttrType.attrLucky:
          // _storage.setPlayerLucky(playerUid, reader.readInt32());
          break;
        case AttrType.attrHp:
          _storage.setPlayerHp(playerUid, reader.readInt32().toInt());
          break;
        default:
          break;
      }
    }
  }
}
