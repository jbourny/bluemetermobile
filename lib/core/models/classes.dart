enum Role {
  Tank,
  Heal,
  DPS,
  Unknown
}

enum Classes {
  Unknown(0, "Unknown", Role.Unknown),
  Stormblade(1, "雷影剑士", Role.DPS),
  FrostMage(2, "冰魔导师", Role.DPS),
  WindKnight(4, "青岚骑士", Role.DPS),
  VerdantOracle(5, "森语者", Role.Heal),
  HeavyGuardian(9, "巨刃守护者", Role.Tank),
  Marksman(11, "神射手", Role.DPS),
  ShieldKnight(12, "神盾骑士", Role.Tank),
  SoulMusician(13, "灵魂乐手", Role.Heal);

  final int id;
  final String name;
  final Role role;

  const Classes(this.id, this.name, this.role);

  static Classes fromId(int? id) {
    if (id == null) return Classes.Unknown;
    return Classes.values.firstWhere(
      (e) => e.id == id,
      orElse: () => Classes.Unknown,
    );
  }
}
