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
          
          Int64 damageValue = Int64.ZERO;
          if (d.hasValue()) {
            damageValue = d.value;
          } else if (d.hasLuckyValue()) {
            damageValue = d.luckyValue;
          }
          
          if (damageValue == Int64.ZERO) continue;

          // Filter out entities that are not players for the DPS list
          // If attacker is not a player, we don't want to show them in the DPS list usually.
          // Unless it's a pet/summon?
          // d.ownerId might link to the summoner.
          
          // If attacker is NOT a player, check if it's a summon (topSummonerId).
          // If topSummonerId is set, use that as the attacker.
          
          // The logic above already does:
          // final attackerRaw = d.topSummonerId != Int64.ZERO ? d.topSummonerId : d.attackerUuid;
          // final isAttackerPlayer = _isUuidPlayerRaw(attackerRaw);
          
          // So if it's a summon, attackerRaw becomes the player's UUID.
          // And isAttackerPlayer becomes true.
          
          // If isAttackerPlayer is false, it means it's a mob/NPC attacking.
          // We only want to record this if the target is a player (Damage Taken).
          
          // Ghost entry issue:
          // If we have an entry with 0 DPS, it might be created but never updated with damage?
          // Or maybe `ensurePlayer` is called somewhere else?
          
          // `_processAoiSyncDelta` calls `_storage.ensurePlayer(targetUuid)` if attrs are present.
          // This is correct, we want to know about players around us.
          
          // But `addDamage` creates `DpsData`.
          
          if (d.type == EDamageType.heal) {
             // Handle Healing
             if (isAttackerPlayer) {
               _storage.addHealing(attackerUuid, targetUuid, damageValue, DateTime.now().millisecondsSinceEpoch);
             }
          } else {
             // Handle Damage
             
             if (d.type == EDamageType.normal || d.type == EDamageType.miss) { 
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
      
      if (msg.hasDeltaInfo()) {
        final deltaInfo = msg.deltaInfo;
        final uuid = deltaInfo.uuid;
        
        // Update CurrentPlayerUUID if it's the first time or changed
        // Note: SyncToMeDeltaInfo.uuid is the raw UUID (shifted left 16 bits + type)
        // We need to shift it right to get the actual player UID.
        
        final playerUid = uuid >> 16;
        
        if (playerUid != Int64.ZERO && _storage.currentPlayerUuid != playerUid) {
          _storage.currentPlayerUuid = playerUid;
          _storage.ensurePlayer(playerUid);
        }

        if (deltaInfo.hasBaseDelta()) {
          _processAoiSyncDelta(deltaInfo.baseDelta);
        }
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
