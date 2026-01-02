import 'dart:typed_data';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';

import '../../protocol/blue_protocol.dart';
import '../../state/data_storage.dart';
import 'message_processor.dart';

class SyncContainerDataProcessor implements IMessageProcessor {
  final DataStorage _storage;

  SyncContainerDataProcessor(this._storage);

  @override
  void process(Uint8List payload) {
    try {
      final syncContainerData = SyncContainerData.fromBuffer(payload);
      if (!syncContainerData.hasVData()) return;
      
      final vData = syncContainerData.vData;
      if (vData.charId == Int64.ZERO) return;

      // CharId is the Raw UUID, so we need to shift it to get the Player UID.
      final playerUid = vData.charId >> 16;
      
      debugPrint("[BM] SyncContainerData received. RawID: ${vData.charId}, PlayerUID: $playerUid");

      // Update current player UID if not set or different? 
      // Usually SyncContainerData is for "Me".
      _storage.currentPlayerUuid = playerUid;
      _storage.ensurePlayer(playerUid);

      if (vData.hasRoleLevel() && vData.roleLevel.level != 0) {
        _storage.setPlayerLevel(playerUid, vData.roleLevel.level);
      }

      if (vData.hasAttr()) {
        if (vData.attr.curHp != Int64.ZERO) {
          _storage.setPlayerHp(playerUid, vData.attr.curHp.toInt());
        }
        if (vData.attr.maxHp != Int64.ZERO) {
          _storage.setPlayerMaxHp(playerUid, vData.attr.maxHp.toInt());
        }
      }

      if (vData.hasCharBase()) {
        debugPrint("[BM] SyncContainerData Name: '${vData.charBase.name}'");
        if (vData.charBase.name.isNotEmpty) {
          _storage.setPlayerName(playerUid, vData.charBase.name);
        } else {
          debugPrint("[BM] SyncContainerData received but Name is empty!");
        }
        if (vData.charBase.fightPoint != 0) {
          _storage.setPlayerCombatPower(playerUid, vData.charBase.fightPoint);
        }
      } else {
        debugPrint("[BM] SyncContainerData received but CharBase is missing!");
      }

      if (vData.hasProfessionList() && vData.professionList.curProfessionId != 0) {
        _storage.setPlayerProfessionId(playerUid, vData.professionList.curProfessionId);
      }

    } catch (e) {
      debugPrint("Error processing SyncContainerData: $e");
    }
  }
}
