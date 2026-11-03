import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class PedometerService extends ChangeNotifier {
  static final PedometerService _instance = PedometerService._internal();
  factory PedometerService() => _instance;
  PedometerService._internal();

  int _dailySteps = 0;
  int _initialSteps = 0;
  bool _isInitialized = false;
  bool _hasPermission = false;
  StreamSubscription<StepCount>? _stepCountStream;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusStream;
  String _pedestrianStatus = 'stopped';

  int get dailySteps => _dailySteps;
  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  String get pedestrianStatus => _pedestrianStatus;

  // Calculate distance (average step length: 0.76 meters)
  double get distanceKm => (_dailySteps * 0.76) / 1000.0;

  // Calculate calories burned (approximate: 0.04 calories per step)
  int get caloriesBurned => (_dailySteps * 0.04).round();

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Request activity recognition permission
      final status = await Permission.activityRecognition.request();
      _hasPermission = status.isGranted;

      if (!_hasPermission) {
        debugPrint('⚠️ Activity recognition permission denied');
        return;
      }

      // Start listening to step count stream
      _stepCountStream = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );

      // Start listening to pedestrian status stream
      _pedestrianStatusStream = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatusChanged,
        onError: _onPedestrianStatusError,
        cancelOnError: false,
      );

      _isInitialized = true;
      debugPrint('✅ Pedometer service initialized');
    } catch (e) {
      debugPrint('❌ Pedometer initialization error: $e');
    }
  }

  void _onStepCount(StepCount event) {
    if (_initialSteps == 0) {
      _initialSteps = event.steps;
    }

    // Calculate daily steps from initial count
    _dailySteps = event.steps - _initialSteps;

    if (_dailySteps < 0) {
      // Handle device reboot or counter reset
      _initialSteps = event.steps;
      _dailySteps = 0;
    }

    notifyListeners();
  }

  void _onStepCountError(error) {
    debugPrint('⚠️ Step count error: $error');
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    _pedestrianStatus = event.status;
    notifyListeners();
  }

  void _onPedestrianStatusError(error) {
    debugPrint('⚠️ Pedestrian status error: $error');
  }

  void resetDaily() {
    _initialSteps = 0;
    _dailySteps = 0;
    notifyListeners();
  }

  @override
  void dispose() {
    _stepCountStream?.cancel();
    _pedestrianStatusStream?.cancel();
    super.dispose();
  }
}

final pedometerService = PedometerService();
