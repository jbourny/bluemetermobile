import 'package:protobuf/protobuf.dart';
import 'package:fixnum/fixnum.dart';

class EDamageType extends ProtobufEnum {
  static const EDamageType normal = EDamageType._(0, 'Normal');
  static const EDamageType miss = EDamageType._(1, 'Miss');
  static const EDamageType heal = EDamageType._(2, 'Heal');
  static const EDamageType immune = EDamageType._(3, 'Immune');
  static const EDamageType fall = EDamageType._(4, 'Fall');
  static const EDamageType absorbed = EDamageType._(5, 'Absorbed');

  static const List<EDamageType> values = <EDamageType> [
    normal, miss, heal, immune, fall, absorbed,
  ];

  static final Map<int, EDamageType> _byValue = ProtobufEnum.initByValue(values);
  static EDamageType? valueOf(int value) => _byValue[value];

  const EDamageType._(super.v, super.n);
}

class SyncDamageInfo extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('SyncDamageInfo', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..e<EDamageType>(4, 'type', PbFieldType.OE, defaultOrMaker: EDamageType.normal, valueOf: EDamageType.valueOf, enumValues: EDamageType.values)
    ..a<int>(5, 'typeFlag', PbFieldType.O3)
    ..aInt64(6, 'value')
    ..aInt64(8, 'luckyValue')
    ..aInt64(11, 'attackerUuid')
    ..a<int>(12, 'ownerId', PbFieldType.OU3)
    ..aInt64(21, 'topSummonerId')
    ..hasRequiredFields = false;

  SyncDamageInfo() : super();
  SyncDamageInfo.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  SyncDamageInfo clone() => SyncDamageInfo()..mergeFromMessage(this);
  @override
  SyncDamageInfo createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static SyncDamageInfo create() => SyncDamageInfo();
  static PbList<SyncDamageInfo> createRepeated() => PbList<SyncDamageInfo>();
  static SyncDamageInfo getDefault() => _defaultInstance ??= create()..freeze();
  static SyncDamageInfo? _defaultInstance;

  EDamageType get type => $_getN(0);
  set type(EDamageType v) { setField(4, v); }
  bool hasType() => $_has(0);
  void clearType() => clearField(4);

  int get typeFlag => $_getIZ(1);
  set typeFlag(int v) { $_setSignedInt32(1, v); }
  bool hasTypeFlag() => $_has(1);
  void clearTypeFlag() => clearField(5);

  Int64 get value => $_getI64(2);
  set value(Int64 v) { $_setInt64(2, v); }
  bool hasValue() => $_has(2);
  void clearValue() => clearField(6);

  Int64 get luckyValue => $_getI64(3);
  set luckyValue(Int64 v) { $_setInt64(3, v); }
  bool hasLuckyValue() => $_has(3);
  void clearLuckyValue() => clearField(8);

  Int64 get attackerUuid => $_getI64(4);
  set attackerUuid(Int64 v) { $_setInt64(4, v); }
  bool hasAttackerUuid() => $_has(4);
  void clearAttackerUuid() => clearField(11);

  int get ownerId => $_getIZ(5);
  set ownerId(int v) { $_setUnsignedInt32(5, v); }
  bool hasOwnerId() => $_has(5);
  void clearOwnerId() => clearField(12);

  Int64 get topSummonerId => $_getI64(6);
  set topSummonerId(Int64 v) { $_setInt64(6, v); }
  bool hasTopSummonerId() => $_has(6);
  void clearTopSummonerId() => clearField(21);
}

class Attr extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('Attr', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..a<int>(1, 'id', PbFieldType.O3)
    ..a<List<int>>(2, 'rawData', PbFieldType.OY)
    ..hasRequiredFields = false;

  Attr() : super();
  Attr.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  Attr clone() => Attr()..mergeFromMessage(this);
  @override
  Attr createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static Attr create() => Attr();
  static PbList<Attr> createRepeated() => PbList<Attr>();
  static Attr getDefault() => _defaultInstance ??= create()..freeze();
  static Attr? _defaultInstance;

  int get id => $_getIZ(0);
  set id(int v) { $_setSignedInt32(0, v); }
  bool hasId() => $_has(0);
  void clearId() => clearField(1);

  List<int> get rawData => $_getN(1);
  set rawData(List<int> v) { $_setBytes(1, v); }
  bool hasRawData() => $_has(1);
  void clearRawData() => clearField(2);
}

class MapAttrValue extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('MapAttrValue', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aOB(1, 'isRemove')
    ..a<List<int>>(2, 'key', PbFieldType.OY)
    ..a<List<int>>(3, 'value', PbFieldType.OY)
    ..hasRequiredFields = false;

  MapAttrValue() : super();
  MapAttrValue.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  MapAttrValue clone() => MapAttrValue()..mergeFromMessage(this);
  @override
  MapAttrValue createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static MapAttrValue create() => MapAttrValue();
  static PbList<MapAttrValue> createRepeated() => PbList<MapAttrValue>();
  static MapAttrValue getDefault() => _defaultInstance ??= create()..freeze();
  static MapAttrValue? _defaultInstance;

  bool get isRemove => $_getBF(0);
  set isRemove(bool v) { $_setBool(0, v); }
  bool hasIsRemove() => $_has(0);
  void clearIsRemove() => clearField(1);

  List<int> get key => $_getN(1);
  set key(List<int> v) { $_setBytes(1, v); }
  bool hasKey() => $_has(1);
  void clearKey() => clearField(2);

  List<int> get value => $_getN(2);
  set value(List<int> v) { $_setBytes(2, v); }
  bool hasValue() => $_has(2);
  void clearValue() => clearField(3);
}

class MapAttr extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('MapAttr', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aOB(1, 'isClear')
    ..a<int>(2, 'id', PbFieldType.O3)
    ..pc<MapAttrValue>(3, 'attrs', PbFieldType.PM, subBuilder: MapAttrValue.create)
    ..hasRequiredFields = false;

  MapAttr() : super();
  MapAttr.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  MapAttr clone() => MapAttr()..mergeFromMessage(this);
  @override
  MapAttr createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static MapAttr create() => MapAttr();
  static PbList<MapAttr> createRepeated() => PbList<MapAttr>();
  static MapAttr getDefault() => _defaultInstance ??= create()..freeze();
  static MapAttr? _defaultInstance;

  bool get isClear => $_getBF(0);
  set isClear(bool v) { $_setBool(0, v); }
  bool hasIsClear() => $_has(0);
  void clearIsClear() => clearField(1);

  int get id => $_getIZ(1);
  set id(int v) { $_setSignedInt32(1, v); }
  bool hasId() => $_has(1);
  void clearId() => clearField(2);

  List<MapAttrValue> get attrs => $_getList(2);
}

class AttrCollection extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('AttrCollection', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aInt64(1, 'uuid')
    ..pc<Attr>(2, 'attrs', PbFieldType.PM, subBuilder: Attr.create)
    ..pc<MapAttr>(3, 'mapAttrs', PbFieldType.PM, subBuilder: MapAttr.create)
    ..hasRequiredFields = false;

  AttrCollection() : super();
  AttrCollection.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  AttrCollection clone() => AttrCollection()..mergeFromMessage(this);
  @override
  AttrCollection createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static AttrCollection create() => AttrCollection();
  static PbList<AttrCollection> createRepeated() => PbList<AttrCollection>();
  static AttrCollection getDefault() => _defaultInstance ??= create()..freeze();
  static AttrCollection? _defaultInstance;

  Int64 get uuid => $_getI64(0);
  set uuid(Int64 v) { $_setInt64(0, v); }
  bool hasUuid() => $_has(0);
  void clearUuid() => clearField(1);

  List<Attr> get attrs => $_getList(1);
  List<MapAttr> get mapAttrs => $_getList(2);
}

class SkillEffect extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('SkillEffect', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aInt64(1, 'uuid')
    ..pc<SyncDamageInfo>(2, 'damages', PbFieldType.PM, subBuilder: SyncDamageInfo.create)
    ..hasRequiredFields = false;

  SkillEffect() : super();
  SkillEffect.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  SkillEffect clone() => SkillEffect()..mergeFromMessage(this);
  @override
  SkillEffect createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static SkillEffect create() => SkillEffect();
  static PbList<SkillEffect> createRepeated() => PbList<SkillEffect>();
  static SkillEffect getDefault() => _defaultInstance ??= create()..freeze();
  static SkillEffect? _defaultInstance;

  Int64 get uuid => $_getI64(0);
  set uuid(Int64 v) { $_setInt64(0, v); }
  bool hasUuid() => $_has(0);
  void clearUuid() => clearField(1);

  List<SyncDamageInfo> get damages => $_getList(1);
}

class AoiSyncDelta extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('AoiSyncDelta', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aInt64(1, 'uuid')
    ..aOM<AttrCollection>(2, 'attrs', subBuilder: AttrCollection.create)
    ..aOM<SkillEffect>(7, 'skillEffects', subBuilder: SkillEffect.create)
    ..hasRequiredFields = false;

  AoiSyncDelta() : super();
  AoiSyncDelta.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  AoiSyncDelta clone() => AoiSyncDelta()..mergeFromMessage(this);
  @override
  AoiSyncDelta createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static AoiSyncDelta create() => AoiSyncDelta();
  static PbList<AoiSyncDelta> createRepeated() => PbList<AoiSyncDelta>();
  static AoiSyncDelta getDefault() => _defaultInstance ??= create()..freeze();
  static AoiSyncDelta? _defaultInstance;

  Int64 get uuid => $_getI64(0);
  set uuid(Int64 v) { $_setInt64(0, v); }
  bool hasUuid() => $_has(0);
  void clearUuid() => clearField(1);

  AttrCollection get attrs => $_getN(1);
  set attrs(AttrCollection v) { setField(2, v); }
  bool hasAttrs() => $_has(1);
  void clearAttrs() => clearField(2);

  SkillEffect get skillEffects => $_getN(2);
  set skillEffects(SkillEffect v) { setField(7, v); }
  bool hasSkillEffects() => $_has(2);
  void clearSkillEffects() => clearField(7);
}

class AoiSyncToMeDelta extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('AoiSyncToMeDelta', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aOM<AoiSyncDelta>(1, 'baseDelta', subBuilder: AoiSyncDelta.create)
    ..aInt64(5, 'uuid')
    ..hasRequiredFields = false;

  AoiSyncToMeDelta() : super();
  AoiSyncToMeDelta.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  AoiSyncToMeDelta clone() => AoiSyncToMeDelta()..mergeFromMessage(this);
  @override
  AoiSyncToMeDelta createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static AoiSyncToMeDelta create() => AoiSyncToMeDelta();
  static PbList<AoiSyncToMeDelta> createRepeated() => PbList<AoiSyncToMeDelta>();
  static AoiSyncToMeDelta getDefault() => _defaultInstance ??= create()..freeze();
  static AoiSyncToMeDelta? _defaultInstance;

  AoiSyncDelta get baseDelta => $_getN(0);
  set baseDelta(AoiSyncDelta v) { setField(1, v); }
  bool hasBaseDelta() => $_has(0);
  void clearBaseDelta() => clearField(1);

  Int64 get uuid => $_getI64(1);
  set uuid(Int64 v) { $_setInt64(1, v); }
  bool hasUuid() => $_has(1);
  void clearUuid() => clearField(5);
}

class SyncToMeDeltaInfo extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('SyncToMeDeltaInfo', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aOM<AoiSyncToMeDelta>(1, 'deltaInfo', subBuilder: AoiSyncToMeDelta.create)
    ..hasRequiredFields = false;

  SyncToMeDeltaInfo() : super();
  SyncToMeDeltaInfo.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  SyncToMeDeltaInfo clone() => SyncToMeDeltaInfo()..mergeFromMessage(this);
  @override
  SyncToMeDeltaInfo createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static SyncToMeDeltaInfo create() => SyncToMeDeltaInfo();
  static PbList<SyncToMeDeltaInfo> createRepeated() => PbList<SyncToMeDeltaInfo>();
  static SyncToMeDeltaInfo getDefault() => _defaultInstance ??= create()..freeze();
  static SyncToMeDeltaInfo? _defaultInstance;

  AoiSyncToMeDelta get deltaInfo => $_getN(0);
  set deltaInfo(AoiSyncToMeDelta v) { setField(1, v); }
  bool hasDeltaInfo() => $_has(0);
  void clearDeltaInfo() => clearField(1);
}

class SyncNearDeltaInfo extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('SyncNearDeltaInfo', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..pc<AoiSyncDelta>(1, 'deltaInfos', PbFieldType.PM, subBuilder: AoiSyncDelta.create)
    ..hasRequiredFields = false;

  SyncNearDeltaInfo() : super();
  SyncNearDeltaInfo.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  SyncNearDeltaInfo clone() => SyncNearDeltaInfo()..mergeFromMessage(this);
  @override
  SyncNearDeltaInfo createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static SyncNearDeltaInfo create() => SyncNearDeltaInfo();
  static PbList<SyncNearDeltaInfo> createRepeated() => PbList<SyncNearDeltaInfo>();
  static SyncNearDeltaInfo getDefault() => _defaultInstance ??= create()..freeze();
  static SyncNearDeltaInfo? _defaultInstance;

  List<AoiSyncDelta> get deltaInfos => $_getList(0);
}

class EEntityType extends ProtobufEnum {
  static const EEntityType entMonster = EEntityType._(1, 'EntMonster');
  static const EEntityType entChar = EEntityType._(10, 'EntChar');

  static const List<EEntityType> values = <EEntityType> [
    entMonster, entChar,
  ];

  static final Map<int, EEntityType> _byValue = ProtobufEnum.initByValue(values);
  static EEntityType? valueOf(int value) => _byValue[value];

  const EEntityType._(super.v, super.n);
}

class Entity extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('Entity', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aInt64(1, 'uuid')
    ..e<EEntityType>(2, 'entType', PbFieldType.OE, defaultOrMaker: EEntityType.entMonster, valueOf: EEntityType.valueOf, enumValues: EEntityType.values)
    ..aOM<AttrCollection>(3, 'attrs', subBuilder: AttrCollection.create)
    ..hasRequiredFields = false;

  Entity() : super();
  Entity.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  Entity clone() => Entity()..mergeFromMessage(this);
  @override
  Entity createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static Entity create() => Entity();
  static PbList<Entity> createRepeated() => PbList<Entity>();
  static Entity getDefault() => _defaultInstance ??= create()..freeze();
  static Entity? _defaultInstance;

  Int64 get uuid => $_getI64(0);
  set uuid(Int64 v) { $_setInt64(0, v); }
  bool hasUuid() => $_has(0);
  void clearUuid() => clearField(1);

  EEntityType get entType => $_getN(1);
  set entType(EEntityType v) { setField(2, v); }
  bool hasEntType() => $_has(1);
  void clearEntType() => clearField(2);

  AttrCollection get attrs => $_getN(2);
  set attrs(AttrCollection v) { setField(4, v); }
  bool hasAttrs() => $_has(2);
  void clearAttrs() => clearField(4);
}

class SyncNearEntities extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('SyncNearEntities', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..pc<Entity>(1, 'appear', PbFieldType.PM, subBuilder: Entity.create)
    ..hasRequiredFields = false;

  SyncNearEntities() : super();
  SyncNearEntities.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  SyncNearEntities clone() => SyncNearEntities()..mergeFromMessage(this);
  @override
  SyncNearEntities createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static SyncNearEntities create() => SyncNearEntities();
  static PbList<SyncNearEntities> createRepeated() => PbList<SyncNearEntities>();
  static SyncNearEntities getDefault() => _defaultInstance ??= create()..freeze();
  static SyncNearEntities? _defaultInstance;

  List<Entity> get appear => $_getList(0);
}

class CharBase extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('CharBase', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aInt64(1, 'charId')
    ..aOS(5, 'name')
    ..a<int>(35, 'fightPoint', PbFieldType.O3)
    ..hasRequiredFields = false;

  CharBase() : super();
  CharBase.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  CharBase clone() => CharBase()..mergeFromMessage(this);
  @override
  CharBase createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static CharBase create() => CharBase();
  static PbList<CharBase> createRepeated() => PbList<CharBase>();
  static CharBase getDefault() => _defaultInstance ??= create()..freeze();
  static CharBase? _defaultInstance;

  Int64 get charId => $_getI64(0);
  set charId(Int64 v) { $_setInt64(0, v); }
  bool hasCharId() => $_has(0);
  void clearCharId() => clearField(1);

  String get name => $_getSZ(1);
  set name(String v) { $_setString(1, v); }
  bool hasName() => $_has(1);
  void clearName() => clearField(5);

  int get fightPoint => $_getIZ(2);
  set fightPoint(int v) { $_setSignedInt32(2, v); }
  bool hasFightPoint() => $_has(2);
  void clearFightPoint() => clearField(35);
}

class ProfessionList extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('ProfessionList', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..a<int>(1, 'curProfessionId', PbFieldType.O3)
    ..hasRequiredFields = false;

  ProfessionList() : super();
  ProfessionList.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  ProfessionList clone() => ProfessionList()..mergeFromMessage(this);
  @override
  ProfessionList createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static ProfessionList create() => ProfessionList();
  static PbList<ProfessionList> createRepeated() => PbList<ProfessionList>();
  static ProfessionList getDefault() => _defaultInstance ??= create()..freeze();
  static ProfessionList? _defaultInstance;

  int get curProfessionId => $_getIZ(0);
  set curProfessionId(int v) { $_setSignedInt32(0, v); }
  bool hasCurProfessionId() => $_has(0);
  void clearCurProfessionId() => clearField(1);
}

class RoleLevel extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('RoleLevel', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..a<int>(1, 'level', PbFieldType.O3)
    ..hasRequiredFields = false;

  RoleLevel() : super();
  RoleLevel.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  RoleLevel clone() => RoleLevel()..mergeFromMessage(this);
  @override
  RoleLevel createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static RoleLevel create() => RoleLevel();
  static PbList<RoleLevel> createRepeated() => PbList<RoleLevel>();
  static RoleLevel getDefault() => _defaultInstance ??= create()..freeze();
  static RoleLevel? _defaultInstance;

  int get level => $_getIZ(0);
  set level(int v) { $_setSignedInt32(0, v); }
  bool hasLevel() => $_has(0);
  void clearLevel() => clearField(1);
}

class UserFightAttr extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('UserFightAttr', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aInt64(1, 'curHp')
    ..aInt64(2, 'maxHp')
    ..hasRequiredFields = false;

  UserFightAttr() : super();
  UserFightAttr.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  UserFightAttr clone() => UserFightAttr()..mergeFromMessage(this);
  @override
  UserFightAttr createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static UserFightAttr create() => UserFightAttr();
  static PbList<UserFightAttr> createRepeated() => PbList<UserFightAttr>();
  static UserFightAttr getDefault() => _defaultInstance ??= create()..freeze();
  static UserFightAttr? _defaultInstance;

  Int64 get curHp => $_getI64(0);
  set curHp(Int64 v) { $_setInt64(0, v); }
  bool hasCurHp() => $_has(0);
  void clearCurHp() => clearField(1);

  Int64 get maxHp => $_getI64(1);
  set maxHp(Int64 v) { $_setInt64(1, v); }
  bool hasMaxHp() => $_has(1);
  void clearMaxHp() => clearField(2);
}

class VData extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('VData', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aInt64(1, 'charId')
    ..aOM<CharBase>(2, 'charBase', subBuilder: CharBase.create)
    ..aOM<UserFightAttr>(16, 'attr', subBuilder: UserFightAttr.create)
    ..aOM<RoleLevel>(22, 'roleLevel', subBuilder: RoleLevel.create)
    ..aOM<ProfessionList>(76, 'professionList', subBuilder: ProfessionList.create)
    ..hasRequiredFields = false;

  VData() : super();
  VData.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  VData clone() => VData()..mergeFromMessage(this);
  @override
  VData createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static VData create() => VData();
  static PbList<VData> createRepeated() => PbList<VData>();
  static VData getDefault() => _defaultInstance ??= create()..freeze();
  static VData? _defaultInstance;

  Int64 get charId => $_getI64(0);
  set charId(Int64 v) { $_setInt64(0, v); }
  bool hasCharId() => $_has(0);
  void clearCharId() => clearField(1);

  CharBase get charBase => $_getN(1);
  set charBase(CharBase v) { setField(2, v); }
  bool hasCharBase() => $_has(1);
  void clearCharBase() => clearField(2);

  UserFightAttr get attr => $_getN(2);
  set attr(UserFightAttr v) { setField(16, v); }
  bool hasAttr() => $_has(2);
  void clearAttr() => clearField(16);

  RoleLevel get roleLevel => $_getN(3);
  set roleLevel(RoleLevel v) { setField(22, v); }
  bool hasRoleLevel() => $_has(3);
  void clearRoleLevel() => clearField(22);

  ProfessionList get professionList => $_getN(4);
  set professionList(ProfessionList v) { setField(76, v); }
  bool hasProfessionList() => $_has(4);
  void clearProfessionList() => clearField(76);
}

class SyncContainerData extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('SyncContainerData', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aOM<VData>(1, 'vData', subBuilder: VData.create)
    ..hasRequiredFields = false;

  SyncContainerData() : super();
  SyncContainerData.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  SyncContainerData clone() => SyncContainerData()..mergeFromMessage(this);
  @override
  SyncContainerData createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static SyncContainerData create() => SyncContainerData();
  static PbList<SyncContainerData> createRepeated() => PbList<SyncContainerData>();
  static SyncContainerData getDefault() => _defaultInstance ??= create()..freeze();
  static SyncContainerData? _defaultInstance;

  VData get vData => $_getN(0);
  set vData(VData v) { setField(1, v); }
  bool hasVData() => $_has(0);
  void clearVData() => clearField(1);
}

class BufferStream extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('BufferStream', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..a<List<int>>(1, 'bufferS', PbFieldType.OY)
    ..hasRequiredFields = false;

  BufferStream() : super();
  BufferStream.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  BufferStream clone() => BufferStream()..mergeFromMessage(this);
  @override
  BufferStream createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static BufferStream create() => BufferStream();
  static PbList<BufferStream> createRepeated() => PbList<BufferStream>();
  static BufferStream getDefault() => _defaultInstance ??= create()..freeze();
  static BufferStream? _defaultInstance;

  List<int> get bufferS => $_getN(0);
  set bufferS(List<int> v) { $_setBytes(0, v); }
  bool hasBufferS() => $_has(0);
  void clearBufferS() => clearField(1);
}

class SyncContainerDirtyData extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('SyncContainerDirtyData', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aOM<BufferStream>(1, 'vData', subBuilder: BufferStream.create)
    ..hasRequiredFields = false;

  SyncContainerDirtyData() : super();
  SyncContainerDirtyData.fromBuffer(List<int> i, [ExtensionRegistry r = ExtensionRegistry.EMPTY]) : super() {
    mergeFromBuffer(i, r);
  }
  
  @override
  SyncContainerDirtyData clone() => SyncContainerDirtyData()..mergeFromMessage(this);
  @override
  SyncContainerDirtyData createEmptyInstance() => create();
  @override
  BuilderInfo get info_ => _i;

  static SyncContainerDirtyData create() => SyncContainerDirtyData();
  static PbList<SyncContainerDirtyData> createRepeated() => PbList<SyncContainerDirtyData>();
  static SyncContainerDirtyData getDefault() => _defaultInstance ??= create()..freeze();
  static SyncContainerDirtyData? _defaultInstance;

  BufferStream get vData => $_getN(0);
  set vData(BufferStream v) { setField(1, v); }
  bool hasVData() => $_has(0);
  void clearVData() => clearField(1);
}
