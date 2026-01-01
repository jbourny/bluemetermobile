enum AttrType {
  unknown(0),
  attrName(1),
  attrId(10),
  attrProfessionId(0xDC),
  attrFightPoint(0x272E),
  attrLevel(0x2710),
  attrRankLevel(0x274C),
  attrCri(0x2B66),
  attrLucky(0x2B7A),
  attrHp(0x2C2E),
  attrMaxHp(0x2C38),
  attrElementFlag(0x646D6C),
  attrReductionLevel(0x64696D),
  attrReduntionId(0x6F6C65),
  attrEnergyFlag(0x543CD3C6),
  
  // Unknown but seen in logs
  attrUnknown50(50);

  final int value;
  const AttrType(this.value);

  static AttrType fromId(int id) {
    try {
      return AttrType.values.firstWhere((e) => e.value == id, orElse: () => AttrType.unknown);
    } catch (e) {
      return AttrType.unknown;
    }
  }

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
