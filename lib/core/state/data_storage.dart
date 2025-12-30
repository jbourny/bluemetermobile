import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_info.dart';
import '../models/dps_data.dart';

class DataStorage extends ChangeNotifier {
  static final DataStorage _instance = DataStorage._internal();
  factory DataStorage() => _instance;
  DataStorage._internal() {
    _loadPersistedData();
  }

  Int64 _currentPlayerUuid = Int64.ZERO;
  Int64 get currentPlayerUuid => _currentPlayerUuid;
  
  set currentPlayerUuid(Int64 value) {
    if (_currentPlayerUuid != value) {
      _currentPlayerUuid = value;
      _persistCurrentPlayerUuid(value);
      notifyListeners();
    }
  }

  Future<void> _loadPersistedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUuidStr = prefs.getString('current_player_uuid');
      if (storedUuidStr != null) {
        _currentPlayerUuid = Int64.parseInt(storedUuidStr);
        debugPrint("[BM] Loaded persisted CurrentPlayerUUID: $_currentPlayerUuid");
      }
    } catch (e) {
      debugPrint("[BM] Error loading persisted data: $e");
    }
  }

  Future<void> _persistCurrentPlayerUuid(Int64 uuid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_player_uuid', uuid.toString());
    } catch (e) {
      debugPrint("[BM] Error persisting CurrentPlayerUUID: $e");
    }
  }
  
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

  void addDamage(Int64 attackerUid, Int64 targetUid, Int64 damage, int tick) {
    // 1. Add Damage Dealt to Attacker
    var attackerData = getOrCreateDpsData(attackerUid);
    if (attackerData.startLoggedTick == null) {
      attackerData.startLoggedTick = tick;
    }
    attackerData.lastLoggedTick = tick;
    attackerData.totalAttackDamage += damage;
    if (attackerData.startLoggedTick != null) {
       attackerData.activeCombatTicks = tick - attackerData.startLoggedTick!;
    }

    // 2. Add Damage Taken to Target
    var targetData = getOrCreateDpsData(targetUid);
    if (targetData.startLoggedTick == null) {
      targetData.startLoggedTick = tick;
    }
    targetData.lastLoggedTick = tick;
    targetData.totalTakenDamage += damage;
    if (targetData.startLoggedTick != null) {
       targetData.activeCombatTicks = tick - targetData.startLoggedTick!;
    }

    notifyListeners();
  }

  void addHeal(Int64 healerUid, Int64 targetUid, Int64 healAmount, int tick) {
    // 1. Add Heal Output to Healer
    var healerData = getOrCreateDpsData(healerUid);
    if (healerData.startLoggedTick == null) {
      healerData.startLoggedTick = tick;
    }
    healerData.lastLoggedTick = tick;
    healerData.totalHeal += healAmount;
    if (healerData.startLoggedTick != null) {
       healerData.activeCombatTicks = tick - healerData.startLoggedTick!;
    }

    // We could also track "Heal Received" on target if needed, but usually HPS is about output.
    
    notifyListeners();
  }

  void reset() {
    _fullDpsDatas.clear();
    // _playerInfoDatas.clear(); // Usually we keep player info?
    notifyListeners();
  }
}
