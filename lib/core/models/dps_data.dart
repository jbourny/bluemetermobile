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
    if (startLoggedTick == null || lastLoggedTick <= startLoggedTick!) return 0.0;
    double seconds = (lastLoggedTick - startLoggedTick!) / 10000000.0;
    if (seconds <= 0) return 0.0;
    return totalAttackDamage.toDouble() / seconds;
  }
}
