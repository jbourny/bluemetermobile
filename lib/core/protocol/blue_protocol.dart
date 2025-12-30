import 'package:protobuf/protobuf.dart';
import 'package:fixnum/fixnum.dart';

class EDamageType extends ProtobufEnum {
  static const EDamageType Normal = EDamageType._(0, 'Normal');
  static const EDamageType Miss = EDamageType._(1, 'Miss');
  static const EDamageType Heal = EDamageType._(2, 'Heal');
  static const EDamageType Immune = EDamageType._(3, 'Immune');
  static const EDamageType Fall = EDamageType._(4, 'Fall');
  static const EDamageType Absorbed = EDamageType._(5, 'Absorbed');

  static const List<EDamageType> values = <EDamageType> [
    Normal, Miss, Heal, Immune, Fall, Absorbed,
  ];

  static final Map<int, EDamageType> _byValue = ProtobufEnum.initByValue(values);
  static EDamageType? valueOf(int value) => _byValue[value];

  const EDamageType._(int v, String n) : super(v, n);
}

class SyncDamageInfo extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('SyncDamageInfo', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..e<EDamageType>(4, 'type', PbFieldType.OE, defaultOrMaker: EDamageType.Normal, valueOf: EDamageType.valueOf, enumValues: EDamageType.values)
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

  SkillEffect get skillEffects => $_getN(1);
  set skillEffects(SkillEffect v) { setField(7, v); }
  bool hasSkillEffects() => $_has(1);
  void clearSkillEffects() => clearField(7);
}

class AoiSyncToMeDelta extends GeneratedMessage {
  static final BuilderInfo _i = BuilderInfo('AoiSyncToMeDelta', package: const PackageName('BlueProto'), createEmptyInstance: create)
    ..aOM<AoiSyncDelta>(1, 'baseDelta', subBuilder: AoiSyncDelta.create)
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
