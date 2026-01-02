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
    if (activeCombatTicks <= 0) return totalAttackDamage.toDouble();
    // Ticks are in milliseconds (from DateTime.now().millisecondsSinceEpoch)
    double seconds = activeCombatTicks / 1000.0;
    // Enforce minimum 1s duration to avoid massive spikes at start of combat
    if (seconds < 1.0) seconds = 1.0;
    return totalAttackDamage.toDouble() / seconds;
  }
  
  // Simple DPS based on total time (start to end)
  double get simpleDps {
    if (startLoggedTick == null) return 0.0;
    double seconds = (lastLoggedTick - startLoggedTick!) / 1000.0;
    // Enforce minimum 1s duration to avoid massive spikes at start of combat
    if (seconds < 1.0) seconds = 1.0;
    return totalAttackDamage.toDouble() / seconds;
  }

  double get simpleHps {
    if (startLoggedTick == null) return 0.0;
    double seconds = (lastLoggedTick - startLoggedTick!) / 1000.0;
    if (seconds < 1.0) seconds = 1.0;
    return totalHeal.toDouble() / seconds;
  }

  double get simpleTakenDps {
    if (startLoggedTick == null) return 0.0;
    double seconds = (lastLoggedTick - startLoggedTick!) / 1000.0;
    if (seconds < 1.0) seconds = 1.0;
    return totalTakenDamage.toDouble() / seconds;
  }
}
