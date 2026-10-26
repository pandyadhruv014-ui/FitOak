import 'package:health/health.dart';
import '../state/daily_tracker_state.dart';

class HealthService {
  static final Health _health = Health();

  static Future<void> syncHealthData() async {
    final types = [
      HealthDataType.STEPS,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.DISTANCE_DELTA,
    ];

    bool requested = await _health.requestAuthorization(types);

    if (requested) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      int steps = await _health.getTotalStepsInInterval(midnight, now) ?? 0;
      
      // Calculate burned calories and total distance
      dailyTracker.syncDeviceHealthData(
        steps: steps,
        distance: (steps * 0.0008), // approximate km
        burnedCals: (steps * 0.04).toInt(),
      );
    }
  }
}