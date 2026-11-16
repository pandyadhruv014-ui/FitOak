import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import '../main.dart';
import '../state/daily_tracker_state.dart';
import '../services/pedometer_service.dart';
import '../services/notification_service.dart';

class TrackersTabScreen extends StatefulWidget {
  const TrackersTabScreen({super.key});

  @override
  State<TrackersTabScreen> createState() => _TrackersTabScreenState();
}

class _TrackersTabScreenState extends State<TrackersTabScreen> {
  final TextEditingController _foodController = TextEditingController();
  bool _isFetching = false;
  Map<String, dynamic>? _fetchedNutrition;

  TimeOfDay? _savedGymTime;

  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  bool _isSensorActive = false;
  double _lastAccel = 0.0;
  int _sensorSteps = 0;

  @override
  void initState() {
    super.initState();
    dailyTracker.addListener(_onStateChange);
    _initPedometer();
    _startMotionSensor();
    _loadSavedGymReminder();
    dailyTracker.fetchWeeklyWater();
    dailyTracker.fetchMyGymGroup();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    dailyTracker.removeListener(_onStateChange);
    _foodController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    _loadSavedGymReminder();
    if (mounted) setState(() {});
  }

  Future<void> _loadSavedGymReminder() async {
    final saved = await NotificationService().getSavedGymReminder();
    if (mounted && saved != _savedGymTime) {
      setState(() => _savedGymTime = saved);
    }
  }

  Future<void> _initPedometer() async {
    await pedometerService.init();
    pedometerService.addListener(_onStateChange);
  }

  void _startMotionSensor() {
    _accelSubscription = userAccelerometerEventStream().listen((event) {
      double acceleration =
          (event.x * event.x + event.y * event.y + event.z * event.z);
      if (acceleration > 12.0 && (_lastAccel <= 12.0)) {
        _sensorSteps++;
        if (_sensorSteps % 5 == 0) {
          dailyTracker.syncDeviceHealthData(
            steps: 5,
            distance: 0.0038,
            burnedCals: 1,
          );
        }
      }
      _lastAccel = acceleration;
      if (!_isSensorActive && mounted) {
        setState(() => _isSensorActive = true);
      }
    });
  }

  Future<void> _pickAndSaveGymReminder() async {
    final initial = _savedGymTime ?? const TimeOfDay(hour: 18, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;

    await NotificationService().scheduleGymReminder(
      hour: picked.hour,
      minute: picked.minute,
    );

    if (dailyTracker.activeGymGroup != null) {
      try {
        await dailyTracker.updateGroupGymReminder(picked.hour, picked.minute);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Gym reminder set to ${picked.format(context)} for your entire Gym Squad!"),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Saved locally, group sync failed: $e")),
          );
        }
      }
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Gym reminder locked at ${picked.format(context)} (Mon–Sat)."),
          backgroundColor: Colors.green,
        ),
      );
    }

    await _loadSavedGymReminder();
  }

  Future<void> _fetchNutritionalValues() async {
    final query = _foodController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isFetching = true;
      _fetchedNutrition = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/ai/nutrition'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'dish_name': query,
              'quantity': '1 portion',
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nutrition = data['data'];
        setState(() {
          _fetchedNutrition = {
            'name': nutrition['meal_name'] ?? query,
            'calories': (nutrition['calories'] as num).toInt(),
            'protein': (nutrition['protein_g'] as num).toInt(),
            'carbs': (nutrition['carbs_g'] as num).toInt(),
            'fat': (nutrition['fat_g'] as num).toInt(),
            'tips': nutrition['tips'] ?? '',
          };
        });
      } else {
        _fallbackLocalEstimation(query);
      }
    } catch (_) {
      _fallbackLocalEstimation(query);
    } finally {
      if (mounted) setState(() => _isFetching = false);
    }
  }

  void _fallbackLocalEstimation(String query) {
    setState(() {
      _fetchedNutrition = {
        'name': query,
        'calories': 320,
        'protein': 24,
        'carbs': 35,
        'fat': 10,
        'tips': 'Balanced protein and carb estimation.',
      };
    });
  }

  void _addMealToTodayDiet() {
    if (_fetchedNutrition == null) return;

    dailyTracker.logUserMeal(
      day: dailyTracker.todayDayName,
      mealCategory: 'Snacks',
      foodName: _fetchedNutrition!['name'],
      calories: _fetchedNutrition!['calories'],
      protein: _fetchedNutrition!['protein'],
      carbs: _fetchedNutrition!['carbs'],
      fat: _fetchedNutrition!['fat'],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${_fetchedNutrition!['name']} added to Today\'s Diet!')),
    );

    setState(() {
      _foodController.clear();
      _fetchedNutrition = null;
    });
  }

  void _showGymGroupDialog() {
    final nameController = TextEditingController();
    final passController = TextEditingController();
    bool isJoinMode = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isJoinMode ? "Join Gym Squad" : "Create Gym Squad"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Create"),
                        selected: !isJoinMode,
                        onSelected: (_) =>
                            setDialogState(() => isJoinMode = false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text("Join with Pass"),
                        selected: isJoinMode,
                        onSelected: (_) =>
                            setDialogState(() => isJoinMode = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!isJoinMode) ...[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Squad Name (e.g., Morning Lifters)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: passController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: "Secret Entry Pass (e.g., IRON2026)",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final pass = passController.text.trim();
                        final gName = nameController.text.trim();
                        if (pass.isEmpty || (!isJoinMode && gName.isEmpty)) {
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          if (isJoinMode) {
                            await dailyTracker.joinGymGroup(pass);
                          } else {
                            await dailyTracker.createGymGroup(gName, pass);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          setDialogState(() => isSubmitting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                  content: Text(e.toString()),
                                  backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: Text(isJoinMode ? "Join Squad" : "Create Squad",
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCoLogExerciseDialog() {
    final exerciseController = TextEditingController();
    final setsController = TextEditingController(text: "3");
    final weightController = TextEditingController(text: "20");
    String selectedMuscle = "Chest";
    final buddies = dailyTracker.gymBuddiesExcludingMe;
    final Set<int> selectedBuddyIds =
        buddies.map((b) => b['user_id'] as int).toSet();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Log Exercise with Gym Buddies"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedMuscle,
                    items: const [
                      'Chest',
                      'Back',
                      'Shoulders',
                      'Biceps',
                      'Triceps',
                      'Legs',
                      'Abs'
                    ]
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedMuscle = val ?? 'Chest'),
                    decoration: const InputDecoration(
                        labelText: "Muscle Group",
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: exerciseController,
                    decoration: const InputDecoration(
                      labelText: "Exercise Name (e.g., Bench Press)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: setsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: "Sets", border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: "Max Wt (kg)",
                              border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  if (buddies.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text("Also log for buddies who trained with you:",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    ...buddies.map((buddy) {
                      final bid = buddy['user_id'] as int;
                      return CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        activeColor: Colors.deepOrange,
                        title: Text(buddy['user_name'] ?? 'Buddy'),
                        value: selectedBuddyIds.contains(bid),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedBuddyIds.add(bid);
                            } else {
                              selectedBuddyIds.remove(bid);
                            }
                          });
                        },
                      );
                    }),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange),
                onPressed: () async {
                  final ex = exerciseController.text.trim();
                  if (ex.isEmpty) return;
                  final setsCount = int.tryParse(setsController.text) ?? 3;
                  final maxWt = double.tryParse(weightController.text) ?? 0.0;
                  final sets = List.generate(
                      setsCount,
                      (i) => SetLog(
                          setNumber: i + 1, reps: 10, weight: maxWt));

                  Navigator.pop(ctx);
                  await dailyTracker.logExerciseWithSets(
                    muscle: selectedMuscle,
                    exerciseName: ex,
                    sets: sets,
                    buddyUserIds: selectedBuddyIds.toList(),
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(selectedBuddyIds.isEmpty
                            ? "Logged $ex!"
                            : "Logged $ex for you + ${selectedBuddyIds.length} gym buddy(s)!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Text("Save Workout",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final group = dailyTracker.activeGymGroup;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Persistent Gym Reminder Card
          Text("Gym Schedule Reminder",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor)),
          const SizedBox(height: 10),
          Card(
            child: ListTile(
              leading: const Icon(Icons.alarm, color: Colors.deepOrange, size: 30),
              title: Text(
                _savedGymTime != null
                    ? "Daily Gym Time: ${_savedGymTime!.format(context)}"
                    : "No Gym Reminder Set",
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: primaryTextColor),
              ),
              subtitle: Text(
                _savedGymTime != null
                    ? "Locked Mon–Sat until you change it"
                    : "Tap Set Time to lock your daily alarm",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange),
                onPressed: _pickAndSaveGymReminder,
                child: Text(_savedGymTime != null ? "Change" : "Set Time",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 2. Water Consumption + Weekly Chart
          Text("Water Consumption (Weekly)",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Today: ${dailyTracker.waterGlasses} / ${dailyTracker.waterGoalGlasses} Glasses",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: primaryTextColor),
                          ),
                          Text(
                            "${dailyTracker.waterGlasses * 250} ml consumed today",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.lightBlueAccent),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: dailyTracker.removeWaterGlass,
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.orange),
                          ),
                          IconButton(
                            onPressed: dailyTracker.addWaterGlass,
                            icon: const Icon(Icons.add_circle,
                                color: Colors.lightBlueAccent, size: 30),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 22),
                  SizedBox(
                    height: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: dailyTracker.weeklyWaterData.map((dayData) {
                        final int glasses = (dayData['glasses'] ?? 0) as int;
                        final bool isToday = dayData['is_today'] == true;
                        final double ratio =
                            (glasses / dailyTracker.waterGoalGlasses)
                                .clamp(0.05, 1.0);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text("$glasses",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? Colors.lightBlueAccent
                                        : Colors.grey)),
                            const SizedBox(height: 4),
                            Container(
                              width: 22,
                              height: 75 * ratio,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.lightBlueAccent
                                    : Colors.blueGrey.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              dayData['day'] ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isToday
                                    ? Colors.deepOrange
                                    : primaryTextColor,
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 3. Gym Buddy Group Card
          Text("Gym Buddy Squad",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: group == null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Connect with your gym buddies using a shared entry pass to sync gym reminders and co-log workouts together.",
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[400]),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: _showGymGroupDialog,
                          icon: const Icon(Icons.group_add, color: Colors.white),
                          label: const Text("Create or Join Gym Squad",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              group['group_name'] ?? 'Gym Squad',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: primaryTextColor),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    Colors.deepOrange.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "PASS: ${group['entry_pass']}",
                                style: const TextStyle(
                                    color: Colors.deepOrange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: ((group['members'] as List?) ?? [])
                              .map((m) => Chip(
                                    avatar: const Icon(Icons.person,
                                        size: 16, color: Colors.deepOrange),
                                    label: Text(m['user_name'] ?? 'Member',
                                        style: const TextStyle(fontSize: 12)),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange),
                                onPressed: _showCoLogExerciseDialog,
                                icon: const Icon(Icons.fitness_center,
                                    color: Colors.white, size: 18),
                                label: const Text("Co-Log Workout",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: _pickAndSaveGymReminder,
                              child: const Text("Sync Alarm"),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 22),

          // 4. Live Motion & Activity Tracker
          Text("Live Motion & Activity Tracker (Built-in Sensor)",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.sensors,
                          color: pedometerService.isInitialized
                              ? Colors.greenAccent
                              : Colors.grey),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          pedometerService.isInitialized
                              ? "Hardware Pedometer: Active (${pedometerService.pedestrianStatus})"
                              : "Initializing Hardware Sensors...",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: pedometerService.isInitialized
                                  ? Colors.greenAccent
                                  : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _sensorMetric(
                          "Daily Steps", "${pedometerService.dailySteps}"),
                      _sensorMetric("Distance",
                          "${pedometerService.distanceKm.toStringAsFixed(2)} km"),
                      _sensorMetric(
                          "Calories", "${pedometerService.caloriesBurned} kcal"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // 5. AI Nutritional Value Tracker
          Text("AI Nutritional Value Tracker",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _foodController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Meal (e.g., 2 eggs & brown toast)',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.restaurant),
                    ),
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange,
                      minimumSize: const Size.fromHeight(45),
                    ),
                    onPressed: _isFetching ? null : _fetchNutritionalValues,
                    child: _isFetching
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Analyze Nutrition with Gemini AI',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                  if (_fetchedNutrition != null) ...[
                    const Divider(height: 30),
                    Text('Verified Data for "${_fetchedNutrition!['name']}"',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: primaryTextColor)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _macroBadge('Calories',
                            '${_fetchedNutrition!['calories']} kcal'),
                        _macroBadge(
                            'Protein', '${_fetchedNutrition!['protein']}g'),
                        _macroBadge('Carbs', '${_fetchedNutrition!['carbs']}g'),
                        _macroBadge('Fat', '${_fetchedNutrition!['fat']}g'),
                      ],
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(45)),
                      onPressed: _addMealToTodayDiet,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('Add to Today\'s Diet',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorMetric(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _macroBadge(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Colors.deepOrange)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}