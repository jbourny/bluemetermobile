import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/player_info.dart';
import '../models/dps_data.dart';
import '../services/database_service.dart';

class DataStorage extends ChangeNotifier {
  static final DataStorage _instance = DataStorage._internal();
  factory DataStorage() => _instance;
  DataStorage._internal();

  Int64 _currentPlayerUuid = Int64.ZERO;
  Int64 get currentPlayerUuid => _currentPlayerUuid;
  
  set currentPlayerUuid(Int64 value) {
    if (_currentPlayerUuid != value) {
      _currentPlayerUuid = value;
      _persistCurrentPlayerUuid(value);
      notifyListeners();
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

  // Combat Timer Logic
  DateTime? _lastActionTime;
  DateTime? _combatStartTime;
  bool _isCombatActive = false;
  Duration combatTimeout = const Duration(seconds: 30);

  Duration get currentCombatDuration {
    if (_combatStartTime == null) return Duration.zero;
    if (_isCombatActive) {
      return DateTime.now().difference(_combatStartTime!);
    }
    if (_lastActionTime != null) {
      return _lastActionTime!.difference(_combatStartTime!);
    }
    return Duration.zero;
  }

  void checkTimeout() {
    if (_isCombatActive && _lastActionTime != null) {
      if (DateTime.now().difference(_lastActionTime!) > combatTimeout) {
        _isCombatActive = false;
        notifyListeners();
      }
    }
  }

  void _onAction() {
    final now = DateTime.now();
    
    // Check for timeout first to handle the case where we are "active" but timed out
    if (_isCombatActive && _lastActionTime != null && now.difference(_lastActionTime!) > combatTimeout) {
      _isCombatActive = false;
    }

    if (!_isCombatActive) {
      // Start new combat
      reset(resetTimer: false); // Don't reset timer fields here, we set them below
      _isCombatActive = true;
      _combatStartTime = now;
    }
    _lastActionTime = now;
  }

  Map<Int64, PlayerInfo> get playerInfoDatas => Map.unmodifiable(_playerInfoDatas);
  
  // Filter DPS datas to only include entities that are identified as players (exist in playerInfoDatas)
  // This hides monsters/NPCs from the DPS list.
  Map<Int64, DpsData> get fullDpsDatas {
    final filtered = <Int64, DpsData>{};
    _fullDpsDatas.forEach((key, value) {
      if (_playerInfoDatas.containsKey(key)) {
        filtered[key] = value;
      }
    });
    return Map.unmodifiable(filtered);
  }

  void updatePlayerInfo(PlayerInfo info) {
    _playerInfoDatas[info.uid] = info;
    _notFoundUids.remove(info.uid);
    DatabaseService().savePlayer(info);
    notifyListeners();
  }
  
  final Set<Int64> _notFoundUids = {};

  Future<PlayerInfo?> getPlayerInfo(Int64 uid) async {
    if (_playerInfoDatas.containsKey(uid)) {
      return _playerInfoDatas[uid];
    }
    if (_notFoundUids.contains(uid)) {
      return null;
    }
    return await _fetchPlayerFromDb(uid);
  }

  Future<PlayerInfo?> _fetchPlayerFromDb(Int64 uid) async {
    try {
      final player = await DatabaseService().getPlayer(uid);
      if (player != null) {
        _playerInfoDatas[uid] = player;
        notifyListeners();
        return player;
      } else {
        _notFoundUids.add(uid);
      }
    } catch (e) {
      debugPrint("[BM] Error fetching player from DB: $e");
    }
    return null;
  }

  DpsData getOrCreateDpsData(Int64 uid) {
    if (!_fullDpsDatas.containsKey(uid)) {
      _fullDpsDatas[uid] = DpsData(uid: uid);
    }
    return _fullDpsDatas[uid]!;
  }

  void addDamage(Int64 attackerUid, Int64 targetUid, Int64 damage, int tick) {
    _onAction();
    // 1. Add Damage Dealt to Attacker
    var attackerData = getOrCreateDpsData(attackerUid);
    attackerData.startLoggedTick ??= tick;
    attackerData.lastLoggedTick = tick;
    attackerData.totalAttackDamage += damage;
    if (attackerData.startLoggedTick != null) {
       attackerData.activeCombatTicks = tick - attackerData.startLoggedTick!;
    }

    // 2. Add Damage Taken to Target
    var targetData = getOrCreateDpsData(targetUid);
    targetData.startLoggedTick ??= tick;
    targetData.lastLoggedTick = tick;
    targetData.totalTakenDamage += damage;
    if (targetData.startLoggedTick != null) {
       targetData.activeCombatTicks = tick - targetData.startLoggedTick!;
    }

    notifyListeners();
  }

  void addHealing(Int64 healerUid, Int64 targetUid, Int64 healAmount, int tick) {
    _onAction();
    // 1. Add Heal Output to Healer
    var healerData = getOrCreateDpsData(healerUid);
    healerData.startLoggedTick ??= tick;
    healerData.lastLoggedTick = tick;
    healerData.totalHeal += healAmount;
    if (healerData.startLoggedTick != null) {
       healerData.activeCombatTicks = tick - healerData.startLoggedTick!;
    }
    
    notifyListeners();
  }

  void reset({bool resetTimer = true}) {
    _fullDpsDatas.clear();
    if (resetTimer) {
      _combatStartTime = null;
      _lastActionTime = null;
      _isCombatActive = false;
    }
    notifyListeners();
  }

  // --- Player Info Setters ---

  void ensurePlayer(Int64 uid) {
    if (!_playerInfoDatas.containsKey(uid)) {
      _playerInfoDatas[uid] = PlayerInfo(uid: uid);
      notifyListeners();
    }
  }

  void setPlayerName(Int64 uid, String name) {
    ensurePlayer(uid);
    _playerInfoDatas[uid]!.name = name;
    debugPrint("[BM] setPlayerName called: UID=$uid, Name=$name");
    notifyListeners();
  }

  void setPlayerProfessionId(Int64 uid, int id) {
    ensurePlayer(uid);
    _playerInfoDatas[uid]!.professionId = id;
    notifyListeners();
  }

  void setPlayerCombatPower(Int64 uid, int value) {
    ensurePlayer(uid);
    _playerInfoDatas[uid]!.combatPower = value;
    notifyListeners();
  }

  void setPlayerLevel(Int64 uid, int value) {
    ensurePlayer(uid);
    _playerInfoDatas[uid]!.level = value;
    notifyListeners();
  }

  void setPlayerHp(Int64 uid, int value) {
    ensurePlayer(uid);
    _playerInfoDatas[uid]!.hp = Int64(value);
    notifyListeners();
  }

  void setPlayerMaxHp(Int64 uid, int value) {
    ensurePlayer(uid);
    _playerInfoDatas[uid]!.maxHp = Int64(value);
    notifyListeners();
  }
}
