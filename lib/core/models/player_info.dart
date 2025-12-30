import 'package:fixnum/fixnum.dart';

class PlayerInfo {
  Int64 uid;
  String? name;
  int? professionId;
  int? combatPower;
  int? level;
  int? rankLevel;
  int? critical;
  int? lucky;
  Int64? maxHp;
  Int64? hp;

  PlayerInfo({
    required this.uid,
    this.name,
    this.professionId,
    this.combatPower,
    this.level,
    this.rankLevel,
    this.critical,
    this.lucky,
    this.maxHp,
    this.hp,
  });

  @override
  String toString() {
    return 'PlayerInfo(uid: $uid, name: $name, professionId: $professionId)';
  }
}
