import 'package:fixnum/fixnum.dart';

class DpsData {
  Int64 uid;
  int? startLoggedTick;
  int lastLoggedTick = 0;
  int activeCombatTicks = 0;
  
  Int64 totalAttackDamage = Int64.ZERO;
  Int64 totalTakenDamage = Int64.ZERO;
  Int64 totalDamageMitigated = Int64.ZERO;
  Int64 totalHeal = Int64.ZERO;
  
  bool isNpcData = false;

  DpsData({required this.uid});

  double get dps {
    if (activeCombatTicks <= 0) return 0.0;
    // Ticks are usually 100ns or similar in C#, need to check conversion.
    // Assuming standard TimeSpan ticks (10,000,000 per second)
    double seconds = activeCombatTicks / 10000000.0;
    if (seconds <= 0) return 0.0;
    return totalAttackDamage.toDouble() / seconds;
  }
  
  // Simple DPS based on total time (start to end)
  double get simpleDps {
    if (startLoggedTick == null) return 0.0;
    if (lastLoggedTick <= startLoggedTick!) {
       // Duration is 0 (single hit or instant). Return total damage as DPS (effectively 1s duration).
       return totalAttackDamage.toDouble();
    }
    double seconds = (lastLoggedTick - startLoggedTick!) / 10000000.0;
    if (seconds <= 0) return totalAttackDamage.toDouble();
    return totalAttackDamage.toDouble() / seconds;
  }

  double get simpleHps {
    if (startLoggedTick == null) return 0.0;
    if (lastLoggedTick <= startLoggedTick!) return totalHeal.toDouble();
    double seconds = (lastLoggedTick - startLoggedTick!) / 10000000.0;
    if (seconds <= 0) return totalHeal.toDouble();
    return totalHeal.toDouble() / seconds;
  }

  double get simpleTakenDps {
    if (startLoggedTick == null) return 0.0;
    if (lastLoggedTick <= startLoggedTick!) return totalTakenDamage.toDouble();
    double seconds = (lastLoggedTick - startLoggedTick!) / 10000000.0;
    if (seconds <= 0) return totalTakenDamage.toDouble();
    return totalTakenDamage.toDouble() / seconds;
  }
}
