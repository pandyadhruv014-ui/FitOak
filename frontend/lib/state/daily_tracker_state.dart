import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';

class SetLog {
  int setNumber;
  int reps;
  double weight;
  bool isSpecialSet;

  SetLog({
    required this.setNumber,
    required this.reps,
    required this.weight,
    this.isSpecialSet = false,
  });
}

class DailyTrackerState extends ChangeNotifier {
  // User Profile & Auth State
  bool isLoggedIn = false;
  String fullName = '';
  String email = '';
  int age = 23;
  double heightCm = 175.0;
  double weightKg = 70.0;
  String fitnessGoal = 'Build Muscle';

  // Theme State
  bool isDarkMode = true;

  DailyTrackerState() {
    loadPersistedData();
  }

  // Load saved session on app startup
  Future<void> loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    fullName = prefs.getString('fullName') ?? '';
    email = prefs.getString('email') ?? '';
    age = prefs.getInt('age') ?? 23;
    heightCm = prefs.getDouble('heightCm') ?? 175.0;
    weightKg = prefs.getDouble('weightKg') ?? 70.0;
    fitnessGoal = prefs.getString('fitnessGoal') ?? 'Build Muscle';
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
    notifyListeners();
  }

  Future<void> saveUserProfile({
    required String name,
    required String userEmail,
    required int userAge,
    required double userHeight,
    required double userWeight,
    required String goal,
  }) async {
    fullName = name;
    email = userEmail;
    age = userAge;
    heightCm = userHeight;
    weightKg = userWeight;
    fitnessGoal = goal;
    isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('fullName', fullName);
    await prefs.setString('email', email);
    await prefs.setInt('age', age);
    await prefs.setDouble('heightCm', heightCm);
    await prefs.setDouble('weightKg', weightKg);
    await prefs.setString('fitnessGoal', fitnessGoal);

    notifyListeners();
  }

  Future<void> logoutUser() async {
    isLoggedIn = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    notifyListeners();
  }

  void toggleTheme(bool value) async {
    isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode);
    notifyListeners();
  }

  // Nutrition & Workouts
  int totalCalories = 0;
  int totalProtein = 0;
  int totalCarbs = 0;
  int totalFat = 0;

  int dailySteps = 0;
  double distanceKm = 0.0;
  int caloriesBurnedFromHealth = 0;
  int caloriesBurnedFromWorkouts = 0;
  bool isHealthPermissionGranted = false;

  int get totalCaloriesBurned => caloriesBurnedFromHealth + caloriesBurnedFromWorkouts;

  final List<Map<String, dynamic>> todayLog = [];
  final List<Map<String, dynamic>> workoutLog = [];

  final Map<String, Map<String, double>> personalRecords = {
    'Chest': {'Incline Bench Press': 80.0, 'Flat Dumbbell Press': 32.0},
    'Back': {'Lat Pulldowns': 70.0, 'Deadlifts': 140.0},
    'Legs': {'Barbell Squats': 120.0},
  };

  final List<Map<String, dynamic>> weeklyProgressData = [
    {'day': 'Mon', 'consumed': 2100, 'burned': 450},
    {'day': 'Tue', 'consumed': 2300, 'burned': 520},
    {'day': 'Wed', 'consumed': 1950, 'burned': 380},
    {'day': 'Thu', 'consumed': 2400, 'burned': 600},
    {'day': 'Fri', 'consumed': 2200, 'burned': 490},
    {'day': 'Sat', 'consumed': 2500, 'burned': 710},
    {'day': 'Sun', 'consumed': 2000, 'burned': 350},
  ];

  Future<void> addFoodItem(String name, int cals, int protein, int carbs, int fat) async {
    totalCalories += cals;
    totalProtein += protein;
    totalCarbs += carbs;
    totalFat += fat;

    todayLog.add({
      'name': name,
      'calories': cals,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'source': 'SQL Database',
    });

    notifyListeners();

    try {
      await http.post(
        Uri.parse('$baseUrl/meals/add'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'calories': cals,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
        }),
      );
    } catch (e) {
      debugPrint("Warning: Could not sync meal to SQL backend: $e");
    }
  }

  Future<void> fetchBackendMeals() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/meals/today'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List meals = data['meals'];

        todayLog.clear();
        totalCalories = 0;
        totalProtein = 0;
        totalCarbs = 0;
        totalFat = 0;

        for (var meal in meals) {
          int cals = meal['calories'];
          int prot = meal['protein'];
          int carb = meal['carbs'];
          int fatVal = meal['fat'];

          totalCalories += cals;
          totalProtein += prot;
          totalCarbs += carb;
          totalFat += fatVal;

          todayLog.add({
            'name': meal['name'],
            'calories': cals,
            'protein': prot,
            'carbs': carb,
            'fat': fatVal,
            'source': 'SQL Database',
          });
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Warning: Could not fetch meals from SQL backend: $e");
    }
  }

  void syncDeviceHealthData({required int steps, required double distance, required int burnedCals}) {
    dailySteps = steps;
    distanceKm = distance;
    caloriesBurnedFromHealth = burnedCals;
    isHealthPermissionGranted = true;
    notifyListeners();
  }

  void logExerciseWithSets({
    required String muscle,
    required String exerciseName,
    required List<SetLog> sets,
  }) {
    int estimatedCals = 0;
    double maxWeightInSession = 0.0;

    for (var set in sets) {
      estimatedCals += ((set.reps * (set.weight > 0 ? set.weight : 15) * 0.04) + 6 + (set.isSpecialSet ? 8 : 0)).round();
      if (set.weight > maxWeightInSession) {
        maxWeightInSession = set.weight;
      }
    }

    caloriesBurnedFromWorkouts += estimatedCals;

    if (!personalRecords.containsKey(muscle)) {
      personalRecords[muscle] = {};
    }
    double currentPR = personalRecords[muscle]![exerciseName] ?? 0.0;
    if (maxWeightInSession > currentPR) {
      personalRecords[muscle]![exerciseName] = maxWeightInSession;
    }

    workoutLog.add({
      'muscle': muscle,
      'exercise': exerciseName,
      'sets': sets,
      'caloriesBurned': estimatedCals,
      'maxWeight': maxWeightInSession,
      'time': DateTime.now(),
    });

    notifyListeners();
  }
}

final dailyTracker = DailyTrackerState();