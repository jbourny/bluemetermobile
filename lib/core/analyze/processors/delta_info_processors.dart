import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:protobuf/protobuf.dart';

import '../../protocol/blue_protocol.dart';
import '../../models/attr_type.dart';
import '../../state/data_storage.dart';
import '../../tools/byte_reader.dart';
import 'message_processor.dart';

abstract class BaseDeltaInfoProcessor implements IMessageProcessor {
  final DataStorage _storage;

  BaseDeltaInfoProcessor(this._storage);

  bool _isUuidPlayerRaw(Int64 uuidRaw) {
    return (uuidRaw & 0xFFFF) == 640;
  }

  Int64 _shiftRight16(Int64 uuidRaw) {
    return uuidRaw >> 16;
  }

  void _processAoiSyncDelta(AoiSyncDelta? delta) {
    if (delta == null) return;

    final targetUuidRaw = delta.uuid;
    if (targetUuidRaw == Int64.ZERO) return;

    final isTargetPlayer = _isUuidPlayerRaw(targetUuidRaw);
    final targetUuid = _shiftRight16(targetUuidRaw);

    // Process Attributes
    if (delta.hasAttrs() && isTargetPlayer) {
      final attrCollection = delta.attrs;
      if (attrCollection.attrs.isNotEmpty) {
        _storage.ensurePlayer(targetUuid);

        for (var attr in attrCollection.attrs) {
          if (attr.id == 0 || attr.rawData.isEmpty) continue;
          final reader = CodedBufferReader(attr.rawData);
          final attrType = AttrType.fromId(attr.id);

          switch (attrType) {
            case AttrType.attrName:
              _storage.setPlayerName(targetUuid, reader.readString());
              break;
            case AttrType.attrProfessionId:
              _storage.setPlayerProfessionId(targetUuid, reader.readInt32());
              break;
            case AttrType.attrFightPoint:
              _storage.setPlayerCombatPower(targetUuid, reader.readInt32());
              break;
            case AttrType.attrLevel:
              _storage.setPlayerLevel(targetUuid, reader.readInt32());
              break;
            case AttrType.attrHp:
              _storage.setPlayerHp(targetUuid, reader.readInt32().toInt());
              break;
            default:
              break;
          }
        }
      }
    }

    // Process Skill Effects (Damage/Healing)
    if (delta.hasSkillEffects()) {
      final skillEffect = delta.skillEffects;
      if (skillEffect.damages.isNotEmpty) {
        for (var d in skillEffect.damages) {
          final skillId = d.ownerId;
          if (skillId == 0) continue;

          final attackerRaw = d.topSummonerId != Int64.ZERO ? d.topSummonerId : d.attackerUuid;
          if (attackerRaw == Int64.ZERO) continue;

          final isAttackerPlayer = _isUuidPlayerRaw(attackerRaw);
          final attackerUuid = _shiftRight16(attackerRaw);

          // Only record if attacker or target is a player (or both)
          // Actually, usually we care if attacker is player (DPS) or target is player (Damage Taken)
          // But for DPS meter, we mostly care about players dealing damage.
          
          // Logic from C# (implied):
          // if (isAttackerPlayer) -> Add Damage Dealt
          // if (isTargetPlayer) -> Add Damage Taken
          
          // Also handle Healing.
          
          final damageValue = d.value;
          final isCrit = d.typeFlag & 1 != 0; // Assuming bit 0 is crit, need to verify C# logic if possible, but usually flags work like this.
          // Wait, C# code for flags wasn't fully visible.
          // But `SyncDamageInfo` has `type` (EDamageType) and `typeFlag`.
          
          if (d.type == EDamageType.heal) {
             // Handle Healing
             if (isAttackerPlayer) {
               _storage.addHealing(attackerUuid, targetUuid, damageValue, DateTime.now().millisecondsSinceEpoch);
             }
          } else {
             // Handle Damage
             // Filter out Miss/Immune/Fall/Absorbed if needed, or count them as 0 damage?
             // Usually `value` is 0 for miss.
             
             if (d.type == EDamageType.normal || d.type == EDamageType.miss) { // Miss might have 0 value
                if (isAttackerPlayer) {
                  _storage.addDamage(attackerUuid, targetUuid, damageValue, DateTime.now().millisecondsSinceEpoch);
                }
             }
          }
        }
      }
    }
  }
}

class SyncToMeDeltaInfoProcessor extends BaseDeltaInfoProcessor {
  SyncToMeDeltaInfoProcessor(super.storage);

  @override
  void process(Uint8List payload) {
    try {
      final msg = SyncToMeDeltaInfo.fromBuffer(payload);
      if (msg.hasDeltaInfo() && msg.deltaInfo.hasBaseDelta()) {
        _processAoiSyncDelta(msg.deltaInfo.baseDelta);
      }
    } catch (e) {
      debugPrint("Error processing SyncToMeDeltaInfo: $e");
    }
  }
}

class SyncNearDeltaInfoProcessor extends BaseDeltaInfoProcessor {
  SyncNearDeltaInfoProcessor(super.storage);

  @override
  void process(Uint8List payload) {
    try {
      final msg = SyncNearDeltaInfo.fromBuffer(payload);
      if (msg.deltaInfos.isNotEmpty) {
        for (var delta in msg.deltaInfos) {
          _processAoiSyncDelta(delta);
        }
      }
    } catch (e) {
      debugPrint("Error processing SyncNearDeltaInfo: $e");
    }
  }
}
