import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
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
  final String backendUrl = "https://backend-um5a.onrender.com";

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

  // --- RESTORED: Weekly Progress Data Getter ---
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

  void toggleTheme(bool val) {
    isDarkMode = val;
    notifyListeners();
  }

  // --- RESTORED: Health Sensors Sync Method ---
  void syncDeviceHealthData({
    required int steps,
    required double distance,
    required int burnedCals,
  }) {
    isHealthPermissionGranted = true;
    dailySteps += steps;
    distanceKm += distance;
    totalCaloriesBurned += burnedCals;
    notifyListeners();
  }

  // --- SESSION MANAGEMENT ---
  Future<void> checkSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    userId = prefs.getInt('userId') ?? prefs.getInt('user_id') ?? 0;
    fullName = prefs.getString('userName') ?? fullName;
    email = prefs.getString('userEmail') ?? email;
    dob = prefs.getString('dob') ?? dob;
    heightCm = prefs.getDouble('heightCm') ?? heightCm;
    weightKg = prefs.getDouble('weightKg') ?? weightKg;

    debugPrint("Session checked: isLoggedIn=$isLoggedIn, userId=$userId");

    if (userId > 0) {
      await fetchBackendMeals();
      await fetchBackendWorkouts();
    }
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
    await prefs.setInt('user_id', id);
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

    await fetchBackendMeals();
    await fetchBackendWorkouts();
    notifyListeners();
  }

  Future<void> _initNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await flutterLocalNotificationsPlugin.initialize(initSettings);
  }

  void updateOrAddPR(String muscle, String exercise, double weight) {
    if (!personalRecords.containsKey(muscle)) {
      personalRecords[muscle] = {};
    }
    personalRecords[muscle]![exercise] = weight;
    notifyListeners();
  }

  // --- MEAL LOGGING & DATABASE SYNC ---
  Future<void> logUserMeal({
    required String day,
    required String mealCategory,
    required String foodName,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
  }) async {
    debugPrint("🍽️ logUserMeal called - Day: $day, Food: $foodName, User ID: $userId");

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

    debugPrint("📊 Attempting to sync to backend. userId=$userId");

    if (userId > 0) {
      try {
        final payload = {
          'user_id': userId,
          'name': "$mealCategory - $foodName",
          'quantity': '1 portion',
          'calories': calories,
          'protein': protein.toDouble(),
          'carbs': carbs.toDouble(),
          'fat': fat.toDouble(),
        };

        debugPrint("📤 Sending to backend: $payload");

        final res = await http
            .post(
              Uri.parse('$backendUrl/api/meals'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload),
            )
            .timeout(const Duration(seconds: 30));

        debugPrint("📥 Backend response: ${res.statusCode} - ${res.body}");

        if (res.statusCode == 200 || res.statusCode == 201) {
          debugPrint("✅ Meal logged successfully to database!");
          await fetchBackendMeals();
        } else {
          debugPrint("❌ Failed to log meal. Status: ${res.statusCode}, Body: ${res.body}");
        }
      } on TimeoutException catch (e) {
        debugPrint("⏱️ Meal logging timeout: $e");
      } catch (e) {
        debugPrint("❌ Error syncing meal to database: $e");
      }
    } else {
      debugPrint("⚠️ userId is 0 or invalid, storing locally only");
      todayLog.add(mealEntry);
      notifyListeners();
    }
  }

  // --- WORKOUT LOGGING & DATABASE SYNC ---
  Future<void> logExerciseWithSets({
    required String muscle,
    required String exerciseName,
    required List<SetLog> sets,
  }) async {
    double maxWeight = 0;
    for (var s in sets) {
      if (s.weight > maxWeight) maxWeight = s.weight;
    }

    updateOrAddPR(muscle, exerciseName, maxWeight);
    int estimatedBurn = (sets.length * 45).clamp(50, 600);
    totalCaloriesBurned += estimatedBurn;

    if (userId > 0) {
      try {
        final res = await http
            .post(
              Uri.parse('$backendUrl/api/workouts'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'user_id': userId,
                'workout_type': 'Strength',
                'muscle': muscle,
                'exercise': exerciseName,
                'sets_count': sets.length,
                'max_weight': maxWeight,
              }),
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode == 200 || res.statusCode == 201) {
          await fetchBackendWorkouts();
        }
      } catch (e) {
        debugPrint("Error syncing workout to database: $e");
      }
    } else {
      workoutLog.add({
        'muscle': muscle,
        'exercise': exerciseName,
        'sets': sets,
        'maxWeight': maxWeight,
        'caloriesBurned': estimatedBurn,
      });
      notifyListeners();
    }
  }

  Future<void> logCardioSession(
      String type, int durationMins, double distance, int calories) async {
    totalCaloriesBurned += calories;
    distanceKm += distance;

    if (userId > 0) {
      try {
        final res = await http
            .post(
              Uri.parse('$backendUrl/api/workouts'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'user_id': userId,
                'workout_type': 'Cardio',
                'muscle': 'Cardio',
                'exercise': type,
                'duration_mins': durationMins,
                'speed_kmh': durationMins > 0 ? (distance / (durationMins / 60.0)) : 0.0,
              }),
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode == 200 || res.statusCode == 201) {
          await fetchBackendWorkouts();
        }
      } catch (e) {
        debugPrint("Error syncing cardio to database: $e");
      }
    } else {
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
  }

  // --- FETCH MEALS FROM DATABASE ---
  Future<void> fetchBackendMeals() async {
    if (userId <= 0) {
      debugPrint("⚠️ Cannot fetch meals: userId is $userId");
      return;
    }

    try {
      debugPrint("📡 Fetching meals for userId: $userId");

      final res = await http
          .get(Uri.parse('$backendUrl/api/meals/$userId'))
          .timeout(const Duration(seconds: 30));

      debugPrint("📥 Response status: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List meals = data['meals'] ?? [];

        todayLog = meals.map<Map<String, dynamic>>((m) {
          return {
            'id': m['id'],
            'name': m['name'] ?? 'Meal',
            'quantity': m['quantity'] ?? '',
            'calories': (m['calories'] ?? 0) as int,
            'protein': (m['protein'] ?? 0.0).toInt(),
            'carbs': (m['carbs'] ?? 0.0).toInt(),
            'fat': (m['fat'] ?? 0.0).toInt(),
          };
        }).toList();

        debugPrint("✅ Fetched ${meals.length} meals successfully");
        notifyListeners();
      } else {
        debugPrint("⚠️ Server returned status ${res.statusCode}");
        todayLog = [];
        notifyListeners();
      }
    } on TimeoutException catch (e) {
      debugPrint("⏱️ Request timeout: $e");
      todayLog = [];
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error fetching backend meals: $e");
      todayLog = [];
      notifyListeners();
    }
  }

  // --- FETCH WORKOUTS FROM DATABASE ---
  Future<void> fetchBackendWorkouts() async {
    if (userId <= 0) {
      debugPrint("⚠️ Cannot fetch workouts: userId is $userId");
      return;
    }

    try {
      debugPrint("📡 Fetching workouts for userId: $userId");

      final res = await http
          .get(Uri.parse('$backendUrl/api/workouts/$userId'))
          .timeout(const Duration(seconds: 30));

      debugPrint("📥 Workouts response: ${res.statusCode}");

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List workouts = data['workouts'] ?? [];

        workoutLog = workouts.map<Map<String, dynamic>>((w) {
          int count = w['sets_count'] ?? 1;
          double weight = (w['max_weight'] ?? 0.0).toDouble();

          List<SetLog> reconstructedSets = List.generate(
            count,
            (i) => SetLog(setNumber: i + 1, reps: 10, weight: weight),
          );

          return {
            'id': w['id'],
            'muscle': w['muscle'] ?? 'General',
            'exercise': w['exercise'] ?? 'Exercise',
            'sets': reconstructedSets,
            'maxWeight': weight,
            'caloriesBurned': w['calories_burned'] ?? 100,
          };
        }).toList();

        debugPrint("✅ Fetched ${workouts.length} workouts successfully");
        notifyListeners();
      } else {
        debugPrint("⚠️ Workouts returned status ${res.statusCode}");
        workoutLog = [];
        notifyListeners();
      }
    } on TimeoutException catch (e) {
      debugPrint("⏱️ Workouts timeout: $e");
      workoutLog = [];
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Error fetching workouts: $e");
      workoutLog = [];
      notifyListeners();
    }
  }

  // --- DELETE MEAL BUTTON ACTION ---
  Future<void> deleteMeal(int mealId) async {
    try {
      final res = await http.delete(Uri.parse('$backendUrl/api/meals/$mealId'));
      if (res.statusCode == 200) {
        await fetchBackendMeals();
      }
    } catch (e) {
      debugPrint("Error deleting meal: $e");
    }
  }

  // --- DELETE WORKOUT BUTTON ACTION ---
  Future<void> deleteWorkout(int workoutId) async {
    try {
      final res = await http.delete(Uri.parse('$backendUrl/api/workouts/$workoutId'));
      if (res.statusCode == 200) {
        await fetchBackendWorkouts();
      }
    } catch (e) {
      debugPrint("Error deleting workout: $e");
    }
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
