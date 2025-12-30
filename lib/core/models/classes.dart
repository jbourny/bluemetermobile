import '../services/translation_service.dart';

enum Role {
  tank,
  heal,
  dps,
  unknown;

  String get localizedName => TranslationService().translate(name);
}

enum Classes {
  unknown(0, "Unknown", Role.unknown),
  stormblade(1, "Stormblade", Role.dps),
  frostMage(2, "FrostMage", Role.dps),
  windKnight(4, "WindKnight", Role.dps),
  verdantOracle(5, "VerdantOracle", Role.heal),
  heavyGuardian(9, "HeavyGuardian", Role.tank),
  marksman(11, "Marksman", Role.dps),
  shieldKnight(12, "ShieldKnight", Role.tank),
  soulMusician(13, "SoulMusician", Role.heal);

  final int id;
  final String _key;
  final Role role;

  const Classes(this.id, this._key, this.role);

  String get name => TranslationService().translate(_key);

  static Classes fromId(int? id) {
    if (id == null) return Classes.unknown;
    return Classes.values.firstWhere(
      (e) => e.id == id,
      orElse: () => Classes.unknown,
    );
  }
}
