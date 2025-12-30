import '../services/translation_service.dart';

enum Role {
  Tank,
  Heal,
  DPS,
  Unknown;

  String get localizedName => TranslationService().translate(name);
}

enum Classes {
  Unknown(0, "Unknown", Role.Unknown),
  Stormblade(1, "Stormblade", Role.DPS),
  FrostMage(2, "FrostMage", Role.DPS),
  WindKnight(4, "WindKnight", Role.DPS),
  VerdantOracle(5, "VerdantOracle", Role.Heal),
  HeavyGuardian(9, "HeavyGuardian", Role.Tank),
  Marksman(11, "Marksman", Role.DPS),
  ShieldKnight(12, "ShieldKnight", Role.Tank),
  SoulMusician(13, "SoulMusician", Role.Heal);

  final int id;
  final String _key;
  final Role role;

  const Classes(this.id, this._key, this.role);

  String get name => TranslationService().translate(_key);

  static Classes fromId(int? id) {
    if (id == null) return Classes.Unknown;
    return Classes.values.firstWhere(
      (e) => e.id == id,
      orElse: () => Classes.Unknown,
    );
  }
}
