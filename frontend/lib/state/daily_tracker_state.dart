import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

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

  String lastLoggedDate = "";

  String get todayDateStr {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String get todayDayName => _getDayOfWeekName(DateTime.now().weekday);

  Future<void> checkAndRotateDailyLog() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = todayDateStr;
    lastLoggedDate = prefs.getString('lastLoggedDate') ?? "";

    if (lastLoggedDate != todayStr) {
      todayLog.clear();
      workoutLog.clear();
      waterGlasses = 0;
      totalCaloriesBurned = 0;

      await prefs.setString('lastLoggedDate', todayStr);
      await prefs.setInt('waterGlasses_$todayStr', 0);
      lastLoggedDate = todayStr;
      notifyListeners();
    } else {
      waterGlasses = prefs.getInt('waterGlasses_$todayStr') ?? waterGlasses;
    }
  }

  String _getDayOfWeekName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Monday';
    }
  }

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

  // --- Water Intake Tracker (Today + Weekly) ---
  int waterGlasses = 0;
  final int waterGoalGlasses = 12;
  List<Map<String, dynamic>> weeklyWaterData = [];

  // --- Gym Buddy Group State ---
  Map<String, dynamic>? activeGymGroup;

  // --- Today's Direct Log ---
  List<Map<String, dynamic>> todayLog = [];
  List<Map<String, dynamic>> workoutLog = [];

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Map<String, Map<String, double>> personalRecords = {};

  Map<String, List<Map<String, dynamic>>> weeklyUserDietLog = {
    'Monday': [],
    'Tuesday': [],
    'Wednesday': [],
    'Thursday': [],
    'Friday': [],
    'Saturday': [],
    'Sunday': [],
  };

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

    final todayWeekday = DateTime.now().weekday;

    return List.generate(7, (index) {
      String fullDay = fullDays[index];
      bool isToday = (index + 1) == todayWeekday;
      List<Map<String, dynamic>> dayMeals =
          isToday ? todayLog : (weeklyUserDietLog[fullDay] ?? []);

      int dayCalories = dayMeals.fold(
          0, (sum, meal) => sum + ((meal['calories'] ?? 0) as int));
      int burnedCalories = isToday ? totalCaloriesBurned : 0;

      return {
        'day': isToday ? 'Today' : days[index],
        'consumed': dayCalories,
        'burned': burnedCalories,
        'exercises': isToday ? workoutLog : [],
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
    _buildLocalWeeklyWaterFallback();
    checkSavedSession();
  }

  void refreshUI() => notifyListeners();

  // --- WATER INTAKE + WEEKLY SYNC ---
  void _buildLocalWeeklyWaterFallback() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayStr = todayDateStr;

    weeklyWaterData = List.generate(7, (i) {
      final d = monday.add(Duration(days: i));
      final dStr =
          "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
      return {
        'date': dStr,
        'day': labels[i],
        'is_today': dStr == todayStr,
        'glasses': dStr == todayStr ? waterGlasses : 0,
        'ml_total': (dStr == todayStr ? waterGlasses : 0) * 250,
      };
    });
  }

  Future<void> addWaterGlass() async {
    await checkAndRotateDailyLog();
    waterGlasses++;
    await _persistAndSyncWater();
  }

  Future<void> removeWaterGlass() async {
    await checkAndRotateDailyLog();
    if (waterGlasses > 0) {
      waterGlasses--;
      await _persistAndSyncWater();
    }
  }

  Future<void> _persistAndSyncWater() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = todayDateStr;
    await prefs.setInt('waterGlasses_$todayStr', waterGlasses);

    for (var dayEntry in weeklyWaterData) {
      if (dayEntry['date'] == todayStr) {
        dayEntry['glasses'] = waterGlasses;
        dayEntry['ml_total'] = waterGlasses * 250;
      }
    }
    notifyListeners();

    if (userId > 0) {
      try {
        await http
            .post(
              Uri.parse('$backendUrl/api/water'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'user_id': userId,
                'glasses': waterGlasses,
                'ml_total': waterGlasses * 250,
                'log_date': todayStr,
              }),
            )
            .timeout(const Duration(seconds: 30));
      } catch (e) {
        debugPrint("Water sync error: $e");
      }
    }
  }

  Future<void> fetchWeeklyWater() async {
    final prefs = await SharedPreferences.getInstance();
    final todayStr = todayDateStr;
    waterGlasses = prefs.getInt('waterGlasses_$todayStr') ?? waterGlasses;
    _buildLocalWeeklyWaterFallback();

    if (userId <= 0) {
      notifyListeners();
      return;
    }

    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/water/weekly/$userId'))
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List list = data['weekly'] ?? [];
        if (list.isNotEmpty) {
          weeklyWaterData = list.map<Map<String, dynamic>>((item) {
            if (item['date'] == todayStr) {
              final remoteGlasses = (item['glasses'] ?? 0) as int;
              if (remoteGlasses > waterGlasses) {
                waterGlasses = remoteGlasses;
                prefs.setInt('waterGlasses_$todayStr', waterGlasses);
              }
              return {
                ...Map<String, dynamic>.from(item),
                'glasses': waterGlasses,
                'ml_total': waterGlasses * 250,
              };
            }
            return Map<String, dynamic>.from(item);
          }).toList();
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Weekly water fetch error: $e");
    }
  }

  void toggleTheme(bool val) {
    isDarkMode = val;
    notifyListeners();
  }

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
    await checkAndRotateDailyLog();
    final prefs = await SharedPreferences.getInstance();
    isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    userId = prefs.getInt('userId') ?? prefs.getInt('user_id') ?? 0;
    fullName = prefs.getString('userName') ?? fullName;
    email = prefs.getString('userEmail') ?? email;
    dob = prefs.getString('dob') ?? dob;
    heightCm = prefs.getDouble('heightCm') ?? heightCm;
    weightKg = prefs.getDouble('weightKg') ?? weightKg;

    if (userId > 0) {
      await Future.wait([
        fetchBackendMeals(),
        fetchBackendWorkouts(),
        fetchWeeklyWater(),
        fetchMyGymGroup(),
      ]);
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

    await checkSavedSession();
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

  // --- MEAL LOGGING & DATE-FILTERED SYNC ---
  Future<void> logUserMeal({
    required String day,
    required String mealCategory,
    required String foodName,
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
  }) async {
    await checkAndRotateDailyLog();
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

    if (userId > 0) {
      try {
        final res = await http
            .post(
              Uri.parse('$backendUrl/api/meals'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'user_id': userId,
                'name': "$mealCategory - $foodName",
                'quantity': '1 portion',
                'calories': calories,
                'protein': protein.toDouble(),
                'carbs': carbs.toDouble(),
                'fat': fat.toDouble(),
                'log_date': todayDateStr,
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (res.statusCode == 200 || res.statusCode == 201) {
          await fetchBackendMeals();
        }
      } catch (e) {
        debugPrint("❌ Error syncing meal: $e");
      }
    } else {
      todayLog.add(mealEntry);
      notifyListeners();
    }
  }

  // --- WORKOUT LOGGING + GYM BUDDY CO-LOGGING ---
  Future<void> logExerciseWithSets({
    required String muscle,
    required String exerciseName,
    required List<SetLog> sets,
    List<int> buddyUserIds = const [],
  }) async {
    await checkAndRotateDailyLog();
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
                'log_date': todayDateStr,
                'buddy_user_ids': buddyUserIds,
                'logged_by_name': fullName,
              }),
            )
            .timeout(const Duration(seconds: 60));
        if (res.statusCode == 200 || res.statusCode == 201) {
          await fetchBackendWorkouts();
        }
      } catch (e) {
        debugPrint("Error syncing workout: $e");
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
    await checkAndRotateDailyLog();
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
                'speed_kmh':
                    durationMins > 0 ? (distance / (durationMins / 60.0)) : 0.0,
                'calories_burned': calories,
                'log_date': todayDateStr,
              }),
            )
            .timeout(const Duration(seconds: 60));
        if (res.statusCode == 200 || res.statusCode == 201) {
          await fetchBackendWorkouts();
        }
      } catch (e) {
        debugPrint("Error syncing cardio: $e");
      }
    } else {
      workoutLog.add({
        'muscle': 'Cardio',
        'exercise': type,
        'sets': <SetLog>[],
        'maxWeight': 0.0,
        'caloriesBurned': calories,
        'durationMins': durationMins,
        'distance': distance,
        'details':
            '$durationMins mins | ${distance.toStringAsFixed(2)} km | $calories kcal',
      });
      notifyListeners();
    }
  }

  // --- FETCH ONLY TODAY'S MEALS FROM DATABASE ---
  Future<void> fetchBackendMeals() async {
    if (userId <= 0) return;
    await checkAndRotateDailyLog();

    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/meals/$userId?date=$todayDateStr'))
          .timeout(const Duration(seconds: 60));

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

        weeklyUserDietLog[todayDayName] = List<Map<String, dynamic>>.from(todayLog);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Error fetching today's meals: $e");
    }
  }

  // --- FETCH ONLY TODAY'S WORKOUTS FROM DATABASE ---
  Future<void> fetchBackendWorkouts() async {
    if (userId <= 0) return;
    await checkAndRotateDailyLog();

    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/workouts/$userId?date=$todayDateStr'))
          .timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List workouts = data['workouts'] ?? [];

        workoutLog = workouts.map<Map<String, dynamic>>((w) {
          String workoutType = (w['workout_type'] ?? 'Strength').toString();
          bool isCardio = workoutType.toLowerCase() == 'cardio';

          int count = w['sets_count'] ?? 1;
          double weight = (w['max_weight'] ?? 0.0).toDouble();
          int durationMins = w['duration_mins'] ?? 0;
          double speedKmh = (w['speed_kmh'] ?? 0.0).toDouble();
          int caloriesBurned = w['calories_burned'] ?? 100;
          String loggedBy = (w['logged_by'] ?? '').toString();

          List<SetLog> reconstructedSets = List.generate(
            count,
            (i) => SetLog(setNumber: i + 1, reps: 10, weight: weight),
          );

          double distance = isCardio && durationMins > 0
              ? (speedKmh * (durationMins / 60.0))
              : 0.0;

          return {
            'id': w['id'],
            'muscle': w['muscle'] ?? 'General',
            'exercise': loggedBy.isNotEmpty
                ? "${w['exercise']} (with $loggedBy)"
                : (w['exercise'] ?? 'Exercise'),
            'sets': reconstructedSets,
            'maxWeight': weight,
            'caloriesBurned': caloriesBurned,
            'durationMins': durationMins,
            'distance': distance,
            'loggedBy': loggedBy,
            'details': isCardio
                ? '$durationMins mins | ${distance.toStringAsFixed(2)} km | $caloriesBurned kcal'
                : null,
          };
        }).toList();

        totalCaloriesBurned = workoutLog.fold(
            0, (sum, workout) => sum + ((workout['caloriesBurned'] ?? 0) as int));

        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Error fetching today's workouts: $e");
    }
  }

  // --- GYM BUDDY GROUP METHODS ---
  Future<void> fetchMyGymGroup() async {
    if (userId <= 0) return;
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/groups/my/$userId'))
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        activeGymGroup = data['group'];
        await _syncGroupReminderIfNewer();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error fetching gym group: $e");
    }
  }

  Future<void> createGymGroup(String groupName, String entryPass) async {
    if (userId <= 0) throw Exception("Please log in first.");
    final res = await http
        .post(
          Uri.parse('$backendUrl/api/groups/create'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': userId,
            'user_name': fullName,
            'group_name': groupName,
            'entry_pass': entryPass,
          }),
        )
        .timeout(const Duration(seconds: 45));

    final data = json.decode(res.body);
    if (res.statusCode == 200) {
      activeGymGroup = data['group'];
      await _syncGroupReminderIfNewer();
      notifyListeners();
    } else {
      throw Exception(data['detail'] ?? "Failed to create group");
    }
  }

  Future<void> joinGymGroup(String entryPass) async {
    if (userId <= 0) throw Exception("Please log in first.");
    final res = await http
        .post(
          Uri.parse('$backendUrl/api/groups/join'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': userId,
            'user_name': fullName,
            'entry_pass': entryPass,
          }),
        )
        .timeout(const Duration(seconds: 45));

    final data = json.decode(res.body);
    if (res.statusCode == 200) {
      activeGymGroup = data['group'];
      await _syncGroupReminderIfNewer();
      notifyListeners();
    } else {
      throw Exception(data['detail'] ?? "Invalid entry pass");
    }
  }

  Future<void> updateGroupGymReminder(int hour, int minute) async {
    if (activeGymGroup == null) return;
    final groupId = activeGymGroup!['id'];
    final res = await http
        .put(
          Uri.parse('$backendUrl/api/groups/$groupId/reminder'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': userId,
            'user_name': fullName,
            'hour': hour,
            'minute': minute,
          }),
        )
        .timeout(const Duration(seconds: 45));

    final data = json.decode(res.body);
    if (res.statusCode == 200) {
      activeGymGroup = data['group'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_group_reminder_ts',
          activeGymGroup!['reminder_updated_at'] ?? '');
      await NotificationService().scheduleGymReminder(
        hour: hour,
        minute: minute,
        updatedByBuddy: fullName,
      );
      notifyListeners();
    } else {
      throw Exception(data['detail'] ?? "Failed to update group reminder");
    }
  }

  Future<void> leaveGymGroup() async {
    if (activeGymGroup == null) return;
    final groupId = activeGymGroup!['id'];
    await http
        .post(Uri.parse('$backendUrl/api/groups/$groupId/leave/$userId'))
        .timeout(const Duration(seconds: 30));
    activeGymGroup = null;
    notifyListeners();
  }

  Future<void> _syncGroupReminderIfNewer() async {
    if (activeGymGroup == null) return;
    final h = activeGymGroup!['gym_reminder_hour'];
    final m = activeGymGroup!['gym_reminder_minute'];
    final updatedAt = (activeGymGroup!['reminder_updated_at'] ?? '').toString();
    final updatedBy = (activeGymGroup!['reminder_updated_by'] ?? '').toString();

    if (h != null && m != null && updatedAt.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncedTs = prefs.getString('last_group_reminder_ts') ?? '';
      if (lastSyncedTs != updatedAt) {
        await prefs.setString('last_group_reminder_ts', updatedAt);
        await NotificationService().scheduleGymReminder(
          hour: h as int,
          minute: m as int,
          updatedByBuddy: updatedBy,
        );
      }
    }
  }

  List<Map<String, dynamic>> get gymBuddiesExcludingMe {
    if (activeGymGroup == null) return [];
    final List members = activeGymGroup!['members'] ?? [];
    return members
        .map((e) => Map<String, dynamic>.from(e))
        .where((m) => m['user_id'] != userId)
        .toList();
  }

  // --- DELETE MEAL / WORKOUT / ACCOUNT ---
  Future<void> deleteMeal(int mealId) async {
    try {
      final res =
          await http.delete(Uri.parse('$backendUrl/api/meals/$mealId'));
      if (res.statusCode == 200) {
        await fetchBackendMeals();
      }
    } catch (e) {
      debugPrint("Error deleting meal: $e");
    }
  }

  Future<void> deleteWorkout(int workoutId) async {
    try {
      final res =
          await http.delete(Uri.parse('$backendUrl/api/workouts/$workoutId'));
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
    activeGymGroup = null;
    notifyListeners();
  }

  Future<void> deleteUserAccount(String password) async {
    if (userId <= 0) throw Exception("No user logged in");
    final res = await http
        .delete(
          Uri.parse('$backendUrl/api/user/delete'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_id': userId, 'password': password}),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 200) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      isLoggedIn = false;
      userId = 0;
      todayLog.clear();
      workoutLog.clear();
      weeklyUserDietLog.forEach((key, value) => value.clear());
      waterGlasses = 0;
      totalCaloriesBurned = 0;
      activeGymGroup = null;
      notifyListeners();
    } else if (res.statusCode == 401) {
      throw Exception("Incorrect password. Please try again.");
    } else {
      final errorData = json.decode(res.body);
      throw Exception(errorData['detail'] ?? "Failed to delete account");
    }
  }
}

final dailyTracker = DailyTrackerState();
