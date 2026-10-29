import 'package:flutter/foundation.dart';

class HydrationModel extends ChangeNotifier {
  final int _dailyGoalMl = 3000; // Default base goal (3.0 L)
  int _currentIntakeMl = 0;
  bool _isCreatineCycle = false;
  final int _creatineExtraWaterMl = 1000; // Extra 1.0 L for creatine cycle

  int get currentIntake => _currentIntakeMl;
  bool get isCreatineCycle => _isCreatineCycle;
  
  // Total target dynamically adjusts based on creatine toggle
  int get targetGoal => _isCreatineCycle ? _dailyGoalMl + _creatineExtraWaterMl : _dailyGoalMl;

  double get progressPercentage => (_currentIntakeMl / targetGoal).clamp(0.0, 1.0);

  void toggleCreatineCycle(bool enabled) {
    _isCreatineCycle = enabled;
    notifyListeners();
  }

  void addWater(int amountMl) {
    _currentIntakeMl += amountMl;
    notifyListeners();
  }

  void resetDaily() {
    _currentIntakeMl = 0;
    notifyListeners();
  }
}