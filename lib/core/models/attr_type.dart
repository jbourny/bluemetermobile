enum AttrType {
  AttrName(1),
  AttrId(10),
  AttrProfessionId(0xDC),
  AttrFightPoint(51),
  AttrLevel(50),
  AttrRankLevel(0x274C),
  AttrCri(0x2B66),
  AttrLucky(0x2B7A),
  AttrHp(52),
  AttrMaxHp(53),
  AttrElementFlag(0x646D6C),
  AttrReductionLevel(0x64696D),
  AttrReduntionId(0x6F6C65),
  AttrEnergyFlag(0x543CD3C6);

  final int value;
  const AttrType(this.value);

  static AttrType? fromValue(int value) {
    try {
      return AttrType.values.firstWhere((e) => e.value == value);
    } catch (e) {
      return null;
    }
  }
  
  // Helper to check if a value matches (since firstWhere throws or returns default)
  static bool isKnown(int value) {
    return AttrType.values.any((e) => e.value == value);
  }
}
