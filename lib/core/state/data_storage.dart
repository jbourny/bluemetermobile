import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import '../models/player_info.dart';
import '../models/dps_data.dart';

class DataStorage extends ChangeNotifier {
  static final DataStorage _instance = DataStorage._internal();
  factory DataStorage() => _instance;
  DataStorage._internal();

  Int64 currentPlayerUuid = Int64.ZERO;
  
  final Map<Int64, PlayerInfo> _playerInfoDatas = {};
  final Map<Int64, DpsData> _fullDpsDatas = {};

  Map<Int64, PlayerInfo> get playerInfoDatas => Map.unmodifiable(_playerInfoDatas);
  Map<Int64, DpsData> get fullDpsDatas => Map.unmodifiable(_fullDpsDatas);

  void updatePlayerInfo(PlayerInfo info) {
    _playerInfoDatas[info.uid] = info;
    notifyListeners();
  }
  
  PlayerInfo? getPlayerInfo(Int64 uid) {
    return _playerInfoDatas[uid];
  }

  DpsData getOrCreateDpsData(Int64 uid) {
    if (!_fullDpsDatas.containsKey(uid)) {
      _fullDpsDatas[uid] = DpsData(uid: uid);
      // If we have player info, check if it's NPC? (Logic to be added)
    }
    return _fullDpsDatas[uid]!;
  }

  void addDamage(Int64 uid, Int64 damage, int tick) {
    var data = getOrCreateDpsData(uid);
    
    if (data.startLoggedTick == null) {
      data.startLoggedTick = tick;
    }
    data.lastLoggedTick = tick;
    data.totalAttackDamage += damage;
    
    // Simple active time calculation (refine later)
    if (data.startLoggedTick != null) {
       data.activeCombatTicks = tick - data.startLoggedTick!;
    }

    notifyListeners();
  }

  void reset() {
    _fullDpsDatas.clear();
    // _playerInfoDatas.clear(); // Usually we keep player info?
    notifyListeners();
  }
}
