import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // --- Auth & Session State ---
  bool isLoggedIn = false;
  int userId = 0;
  String dob = "";

  // --- Profile Data ---
  String fullName = "Dhruv Pandya";
  String email = "user@fitoak.com";
  int age = 22;
  double heightCm = 178;
  double weightKg = 72;
  String fitnessGoal = "Build Muscle";
  bool isDarkMode = true;

  // --- Health Sensor Integration ---
  bool isHealthPermissionGranted = false;
  int dailySteps = 0;
  double distanceKm = 0.0;
  int totalCaloriesBurned = 0;

  // --- Water Intake Tracker ---
  int waterGlasses = 0;
  final int waterGoalGlasses = 12;

  // --- Today's Direct Log ---
  List<Map<String, dynamic>> todayLog = [];
  List<Map<String, dynamic>> workoutLog = [];

  // --- Notifications Plugin ---
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // --- Personal Best PR Records ---
  Map<String, Map<String, double>> personalRecords = {};

  // --- USER-ENTERED WEEKLY DIET LOG (Mon-Sun) ---
  Map<String, List<Map<String, dynamic>>> weeklyUserDietLog = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
    'Saturday': [],
    'Sunday': [],
  };

  // Dynamic Weekly Consumed Aggregator for Chart
  List<Map<String, dynamic>> get weeklyProgressData {
    List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    List<String> fullDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];

    return List.generate(7, (index) {
      String fullDay = fullDays[index];
      List<Map<String, dynamic>> dayMeals = weeklyUserDietLog[fullDay] ?? [];

      int dayCalories =
          dayMeals.fold(0, (sum, meal) => sum + ((meal['calories'] ?? 0) as int));

      return {
        'day': days[index],
        'consumed': dayCalories,
        'burned': (index == 0) ? totalCaloriesBurned : 400 + (index * 50),
      };
    });
  }

  // Today's Macros Calculated from Logged Meals
  int get totalCalories =>
      todayLog.fold(0, (sum, item) => sum + ((item['calories'] ?? 0) as int));
  int get totalProtein =>
      todayLog.fold(0, (sum, item) => sum + ((item['protein'] ?? 0) as int));
  int get totalCarbs =>
      todayLog.fold(0, (sum, item) => sum + ((item['carbs'] ?? 0) as int));
  int get totalFat =>
      todayLog.fold(0, (sum, item) => sum + ((item['fat'] ?? 0) as int));

  DailyTrackerState() {
    _initNotifications();
    checkSavedSession();
  }

  // --- Session Management Methods (Required by main, auth, account screens) ---
  Future<void> checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    userId = prefs.getInt('userId') ?? 0;
    fullName = prefs.getString('userName') ?? fullName;
    email = prefs.getString('userEmail') ?? email;
    dob = prefs.getString('dob') ?? dob;
    heightCm = prefs.getDouble('heightCm') ?? heightCm;
    weightKg = prefs.getDouble('weightKg') ?? weightKg;
    notifyListeners();
  }

  Future<void> saveUserSession({
    required int id,
    required String name,
    required String userEmail,
    String dobVal = "",
    double height = 0.0,
    double weight = 0.0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('userId', id);
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', userEmail);
    await prefs.setString('dob', dobVal);
    if (height > 0) await prefs.setDouble('heightCm', height);
    if (weight > 0) await prefs.setDouble('weightKg', weight);

    isLoggedIn = true;
    userId = id;
    fullName = name;
    email = userEmail;
    if (dobVal.isNotEmpty) dob = dobVal;
    if (height > 0) heightCm = height;
    if (weight > 0) weightKg = weight;
    notifyListeners();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  Future<void> checkAndSendDinnerReminder() async {
    if (todayLog.isEmpty) {
      const androidDetails = AndroidNotificationDetails(
        'fitoak_reminder',
        'Diet Reminders',
        channelDescription: 'Reminds user to log today\'s meals after dinner',
        importance: Importance.high,
        priority: Priority.high,
      );
      const notificationDetails = NotificationDetails(android: androidDetails);
      await flutterLocalNotificationsPlugin.show(
        0,
        'FitOak Meal Logger Reminder 🍽️',
        'You haven\'t logged your meals for today yet! Tap to log your diet before bed.',
        notificationDetails,
      );
      debugPrint("Triggered post-dinner missing diet log notification.");
    }
  }

  void toggleTheme(bool val) {
    isDarkMode = val;
    notifyListeners();
  }

  void addWaterGlass() {
    waterGlasses++;
    notifyListeners();
  }

  void removeWaterGlass() {
    if (waterGlasses > 0) {
      waterGlasses--;
      notifyListeners();
    }
  }

  // Logs meal directly into Today's Dashboard & Weekly Log
  void logUserMeal({
    required String day,
    required String mealCategory,
    required String foodName,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
  }) {
    final mealEntry = {
      'category': mealCategory,
      'name': foodName,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
    };

    if (weeklyUserDietLog.containsKey(day)) {
      weeklyUserDietLog[day]!.add(mealEntry);
    }

    todayLog.add(mealEntry);
    notifyListeners();
  }

  void updateOrAddPR(String muscle, String exercise, double weight) {
    if (!personalRecords.containsKey(muscle)) {
      personalRecords[muscle] = {};
    }
    personalRecords[muscle]![exercise] = weight;
    notifyListeners();
  }

  void logExerciseWithSets({
    required String muscle,
    required String exerciseName,
    required List<SetLog> sets,
  }) {
    double maxWeight = 0;
    for (var s in sets) {
      if (s.weight > maxWeight) maxWeight = s.weight;
    }

    updateOrAddPR(muscle, exerciseName, maxWeight);

    int estimatedBurn = (sets.length * 45).clamp(50, 600);
    totalCaloriesBurned += estimatedBurn;

    workoutLog.add({
      'muscle': muscle,
      'exercise': exerciseName,
      'sets': sets,
      'maxWeight': maxWeight,
      'caloriesBurned': estimatedBurn,
    });
    notifyListeners();
  }

  void logCardioSession(
      String type, int durationMins, double distance, int calories) {
    totalCaloriesBurned += calories;
    distanceKm += distance;
    workoutLog.add({
      'muscle': 'Cardio',
      'exercise': type,
      'sets': <SetLog>[],
      'maxWeight': 0.0,
      'caloriesBurned': calories,
      'details': '$durationMins mins | ${distance.toStringAsFixed(2)} km',
    });
    notifyListeners();
  }

  void syncDeviceHealthData(
      {required int steps, required double distance, required int burnedCals}) {
    isHealthPermissionGranted = true;
    dailySteps += steps;
    distanceKm += distance;
    totalCaloriesBurned += burnedCals;
    notifyListeners();
  }

  Future<void> fetchBackendMeals() async {
    notifyListeners();
  }

  Future<void> logoutUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    isLoggedIn = false;
    userId = 0;
    todayLog.clear();
    workoutLog.clear();
    weeklyUserDietLog.forEach((key, value) => value.clear());
    waterGlasses = 0;
    notifyListeners();
  }
}

final dailyTracker = DailyTrackerState();