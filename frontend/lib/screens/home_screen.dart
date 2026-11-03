import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:http/http.dart' as http;
import '../state/daily_tracker_state.dart';
import '../services/notification_service.dart';
import '../widgets/custom_loading_switch.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isReminderEnabled = true;
  TimeOfDay selectedGymTime = const TimeOfDay(hour: 18, minute: 0);
  List<int> selectedRestDays = [7];

  double waterLiters = 1.25;
  final double baseWaterGoalLiters = 3.5;
  bool isCreatineCycle = false;
  final double creatineExtraWaterLiters = 1.0;

  double get effectiveWaterGoal =>
      isCreatineCycle ? baseWaterGoalLiters + creatineExtraWaterLiters : baseWaterGoalLiters;

  @override
  void initState() {
    super.initState();
    dailyTracker.addListener(_updateUi);
    dailyTracker.fetchBackendMeals();
    dailyTracker.fetchBackendWorkouts();
  }

  @override
  void dispose() {
    dailyTracker.removeListener(_updateUi);
    super.dispose();
  }

  void _updateUi() {
    if (mounted) setState(() {});
  }

  void _openSubPage(String title, Widget child) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Welcome, ${dailyTracker.fullName.isNotEmpty ? dailyTracker.fullName : 'User'} 👋",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 1. TODAY'S PROGRESS TILE
            _buildNavigationCard(
              context,
              title: "Today's progress",
              subtitle: "Activity, Steps, Macros & Completed Exercises",
              icon: Icons.directions_walk,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage("Today's progress", _buildTodaysProgressContent(context)),
            ),
            const SizedBox(height: 12),

            // 2. PROGRESS OVERVIEW TILE
            _buildNavigationCard(
              context,
              title: "Progress Overview",
              subtitle: "Weekly Exercises & Chart Stats",
              icon: Icons.bar_chart,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage("Progress Overview", const ProgressOverviewSubPage()),
            ),
            const SizedBox(height: 12),

            // 3. INSTANT AI NUTRITION ANALYZER TILE
            _buildNavigationCard(
              context,
              title: "FitOak Nutrition Analyzer",
              subtitle: "Analyze custom dishes & portion macros",
              icon: Icons.auto_awesome,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage("FitOak Nutrition Analyzer", const NutritionAnalyzerSubPage()),
            ),
            const SizedBox(height: 12),

            // 4. DAILY REMINDERS & HYDRATION TILE
            _buildNavigationCard(
              context,
              title: "Daily Reminders & Hydration",
              subtitle: "Gym Remainder & Water Tracker",
              icon: Icons.alarm,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage(
                "4. Daily Reminders & Hydration",
                _buildRemindersAndHydrationContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryTextColor,
    required Color? secondaryTextColor,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: Colors.deepOrange, size: 28),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
        subtitle: Text(subtitle, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
        trailing: Icon(Icons.arrow_forward_ios, color: secondaryTextColor, size: 16),
        onTap: onTap,
      ),
    );
  }

  // --- SUB PAGE 1: TODAY'S PROGRESS ---
  Widget _buildTodaysProgressContent(BuildContext context) {
    final netCalories = (dailyTracker.totalCalories - dailyTracker.totalCaloriesBurned).clamp(0, 10000);
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Daily Motion Sensors", style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                    Text(
                      dailyTracker.isHealthPermissionGranted ? "Synced" : "Sensor Active",
                      style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _activityMetric("Steps", "${dailyTracker.dailySteps}", "Pedometer"),
                    _activityMetric("Distance", "${dailyTracker.distanceKm.toStringAsFixed(2)} km", "Motion"),
                    _activityMetric("Burned", "${dailyTracker.totalCaloriesBurned} kcal", "Motion + Workouts"),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(child: _buildStatCard(context, 'Net Calories', '$netCalories kcal', Colors.deepOrange, Icons.local_fire_department)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(context, 'Protein', '${dailyTracker.totalProtein} / 150 g', Colors.blue, Icons.fitness_center)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildStatCard(context, 'Carbs', '${dailyTracker.totalCarbs} / 250 g', Colors.green, Icons.grain)),
            const SizedBox(width: 10),
            Expanded(child: _buildStatCard(context, 'Fats', '${dailyTracker.totalFat} / 70 g', Colors.amber, Icons.opacity)),
          ],
        ),
        const SizedBox(height: 24),

        Row(
          children: [
            const Icon(Icons.fitness_center, color: Colors.deepOrange, size: 22),
            const SizedBox(width: 8),
            Text(
              "Today's Completed Exercises",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor),
            ),
          ],
        ),
        const SizedBox(height: 12),

        dailyTracker.workoutLog.isEmpty
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Center(
                    child: Text(
                      "No exercises logged yet today.",
                      style: TextStyle(color: secondaryTextColor),
                    ),
                  ),
                ),
              )
            : Column(
                children: dailyTracker.workoutLog.map((item) {
                  final workoutId = item['id'];
                  final muscle = (item['muscle'] ?? '').toString();
                  final isCardio = muscle.toLowerCase() == 'cardio' || item['details'] != null;

                  final String? assetPath = _getMuscleAssetPath(muscle);

                  String subtitleText = "";
                  if (isCardio) {
                    subtitleText = item['details'] ?? "Cardio Session Logged";
                  } else {
                    List<SetLog> sets = (item['sets'] ?? <SetLog>[]) as List<SetLog>;
                    subtitleText = "${sets.length} sets logged | Max Weight: ${item['maxWeight'] ?? 0.0} kg";
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Slidable(
                      key: Key((workoutId ?? item['exercise']).toString()),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (context) async {
                              if (workoutId != null) {
                                await dailyTracker.deleteWorkout(workoutId);
                              } else {
                                dailyTracker.workoutLog.remove(item);
                                dailyTracker.refreshUI();
                              }
                            },
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Remove',
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ],
                      ),
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: assetPath != null
                                ? Image.asset(
                                    assetPath,
                                    width: 28,
                                    height: 28,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.fitness_center,
                                      color: Colors.deepOrange,
                                      size: 24,
                                    ),
                                  )
                                : Icon(
                                    isCardio ? Icons.directions_run : Icons.fitness_center,
                                    color: isCardio ? Colors.blueAccent : Colors.deepOrange,
                                    size: 24,
                                  ),
                          ),
                          title: Text("${item['muscle']} - ${item['exercise']}",
                              style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                          subtitle: Text(subtitleText),
                          trailing: Text(
                            "-${item['caloriesBurned']} kcal",
                            style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
      ],
    );
  }

  // Maps target muscle groups to local PNG asset paths, returning null for cardio
  String? _getMuscleAssetPath(String muscle) {
    switch (muscle.toLowerCase().trim()) {
      case 'abs':
      case 'core':
        return 'assets/icons/abs.png';
      case 'back':
        return 'assets/icons/back.png';
      case 'biceps':
      case 'arms':
        return 'assets/icons/biceps.png';
      case 'chest':
        return 'assets/icons/chest.png';
      case 'legs':
        return 'assets/icons/legs.png';
      case 'shoulders':
        return 'assets/icons/shoulders.png';
      case 'triceps':
        return 'assets/icons/triceps.png';
      default:
        return null; 
    }
  }

  Widget _buildRemindersAndHydrationContent(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return StatefulBuilder(
      builder: (context, setSubState) {
        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Gym Reminder Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                        CustomLoadingSwitch(
                          value: isReminderEnabled,
                          onChanged: (val) async {
                            setSubState(() => isReminderEnabled = val);
                            setState(() => isReminderEnabled = val);
                            if (val) {
                              await NotificationService().scheduleGymReminder(
                                hour: selectedGymTime.hour,
                                minute: selectedGymTime.minute,
                                restDays: selectedRestDays,
                              );
                            } else {
                              await NotificationService().cancelReminders();
                            }
                          },
                        ),
                      ],
                    ),
                    if (isReminderEnabled) ...[
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.alarm, color: Colors.deepOrange),
                        title: Text("Time: ${selectedGymTime.format(context)}", style: TextStyle(color: primaryTextColor)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                          onPressed: () async {
                            final TimeOfDay? picked = await showTimePicker(
                              context: context,
                              initialTime: selectedGymTime,
                            );
                            if (picked != null) {
                              setSubState(() => selectedGymTime = picked);
                              setState(() => selectedGymTime = picked);
                              await NotificationService().scheduleGymReminder(
                                hour: picked.hour,
                                minute: picked.minute,
                                restDays: selectedRestDays,
                              );
                            }
                          },
                          child: const Text("Set Time", style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Water Consumption", style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                        Text(
                          "${waterLiters.toStringAsFixed(2)} / ${effectiveWaterGoal.toStringAsFixed(2)} L",
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (waterLiters / effectiveWaterGoal).clamp(0.0, 1.0),
                      backgroundColor: Colors.blue.withValues(alpha: 0.2),
                      color: Colors.blueAccent,
                      minHeight: 10,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Creatine Cycle (+1.0 L)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryTextColor)),
                        CustomLoadingSwitch(
                          value: isCreatineCycle,
                          onChanged: (val) {
                            setSubState(() => isCreatineCycle = val);
                            setState(() => isCreatineCycle = val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            setSubState(() => waterLiters = (waterLiters + 0.25).clamp(0.0, 10.0));
                            setState(() {});
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("+250 ml"),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            setSubState(() => waterLiters = (waterLiters + 0.50).clamp(0.0, 10.0));
                            setState(() {});
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("+500 ml"),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _activityMetric(String label, String value, String subtext) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Text(subtext, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, Color color, IconData icon) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700], fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

// --- NUTRITION ANALYZER INNER SUB-PAGE ---
class NutritionAnalyzerSubPage extends StatefulWidget {
  const NutritionAnalyzerSubPage({super.key});

  @override
  State<NutritionAnalyzerSubPage> createState() => _NutritionAnalyzerSubPageState();
}

class _NutritionAnalyzerSubPageState extends State<NutritionAnalyzerSubPage> {
  final TextEditingController _dishController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _errorMessage;

  Future<void> _analyze() async {
    final dish = _dishController.text.trim();
    final quantity = _quantityController.text.trim();

    if (dish.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await http.post(
        Uri.parse('https://backend-um5a.onrender.com/api/ai/nutrition'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'dish_name': dish,
          'quantity': quantity.isNotEmpty ? quantity : '1 portion',
        }),
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        setState(() {
          _result = data;
        });
      } else {
        setState(() {
          _errorMessage = "Analysis failed (Server status ${res.statusCode})";
        });
      }
    } catch (e) {
      debugPrint("Analysis error: $e");
      setState(() {
        _errorMessage = "Connection error. Please try again.";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Enter Food Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                const SizedBox(height: 12),
                TextField(
                  controller: _dishController,
                  enabled: !_loading,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: "Food / Dish Name",
                    hintText: "e.g., Paneer Tikka or Oats Bowl",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _quantityController,
                  enabled: !_loading,
                  style: TextStyle(color: primaryTextColor),
                  decoration: InputDecoration(
                    labelText: "Quantity / Portion Size",
                    hintText: "e.g., 200g or 2 pieces or 1 bowl",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _loading ? null : _analyze,
                    icon: _loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.auto_awesome, color: Colors.black),
                    label: Text(_loading ? "Analyzing Nutrients..." : "Analyze Nutrients",
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        if (_result != null) ...[
          const SizedBox(height: 20),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Macro Breakdown Table", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                      const Icon(Icons.table_chart, color: Colors.orange),
                    ],
                  ),
                  const Divider(height: 20),
                  Table(
                    border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    children: [
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(10), child: Text("Food Item", style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text("${_result!['meal_name']}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                      ]),
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(10), child: Text("Calories", style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text("${_result!['calories']} kcal")),
                      ]),
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(10), child: Text("Protein", style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text("${_result!['protein_g']} g")),
                      ]),
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(10), child: Text("Carbs", style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text("${_result!['carbs_g']} g")),
                      ]),
                      TableRow(children: [
                        const Padding(padding: EdgeInsets.all(10), child: Text("Fat", style: TextStyle(fontWeight: FontWeight.bold))),
                        Padding(padding: const EdgeInsets.all(10), child: Text("${_result!['fat_g']} g")),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// --- SUB PAGE 2: PROGRESS OVERVIEW WITH GENUINE READINGS ---
class ProgressOverviewSubPage extends StatefulWidget {
  const ProgressOverviewSubPage({super.key});

  @override
  State<ProgressOverviewSubPage> createState() => _ProgressOverviewSubPageState();
}

class _ProgressOverviewSubPageState extends State<ProgressOverviewSubPage> {
  bool isPieChartMode = false;

  void _showWeekdayExercisesSubWindow(BuildContext context, Map<String, dynamic> dayData) {
    final dayName = dayData['day'] ?? 'Day';
    final burned = dayData['burned'] ?? 0;
    final exercises = (dayData['exercises'] as List<dynamic>?) ?? [];
    final hasDoneExercises = burned > 0 || exercises.isNotEmpty || (dayName == "Today" && dailyTracker.workoutLog.isNotEmpty);

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final primaryTextColor = theme.colorScheme.onSurface;

        return AlertDialog(
          backgroundColor: theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
          ),
          title: Row(
            children: [
              Icon(
                hasDoneExercises ? Icons.check_circle : Icons.cancel,
                color: hasDoneExercises ? Colors.green : Colors.red,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text("$dayName Exercises", style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Burned: $burned kcal", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                const Divider(height: 16),
                if (!hasDoneExercises)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text("No exercises performed on this day.", style: TextStyle(color: Colors.grey)),
                  )
                else if (dayName == "Today" && dailyTracker.workoutLog.isNotEmpty)
                  ...dailyTracker.workoutLog.map((item) {
                    final muscle = item['muscle'] ?? '';
                    final isCardio = muscle.toLowerCase() == 'cardio' || item['details'] != null;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isCardio ? Icons.directions_run : Icons.fitness_center,
                        color: isCardio ? Colors.blueAccent : Colors.orange,
                        size: 18,
                      ),
                      title: Text("${item['muscle']} - ${item['exercise']}", style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                      subtitle: Text(isCardio ? "${item['details']}" : "Burned: ${item['caloriesBurned']} kcal"),
                    );
                  })
                else
                  ...exercises.map((item) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.fitness_center, color: Colors.orange, size: 18),
                      title: Text(item['name'] ?? item['exercise'] ?? 'Exercise', style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                      subtitle: Text("Sets: ${item['sets'] ?? 3} | Burned: ${item['calories'] ?? 100} kcal"),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Close", style: TextStyle(color: Colors.orange)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPieChartMode ? "Pie Chart View" : "Bar Chart View",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor),
                    ),
                    Row(
                      children: [
                        Text("Pie Chart", style: TextStyle(fontSize: 12, color: theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700])),
                        const SizedBox(width: 8),
                        CustomLoadingSwitch(
                          value: isPieChartMode,
                          onChanged: (val) => setState(() => isPieChartMode = val),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 20),
                isPieChartMode ? _buildPieChartView() : _buildBarChartView(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.date_range, color: Colors.deepOrange, size: 20),
                    const SizedBox(width: 8),
                    Text("Weekly Done Exercises", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
                  ],
                ),
                const SizedBox(height: 4),
                Text("Tap any weekday to view performed exercises in a sub-window",
                    style: TextStyle(fontSize: 11, color: theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700])),
                const Divider(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dailyTracker.weeklyProgressData.length,
                  itemBuilder: (context, index) {
                    final dayData = dailyTracker.weeklyProgressData[index];
                    final dayName = dayData['day'] ?? '';
                    final burned = (dayData['burned'] as num?)?.toInt() ?? 0;
                    final exercises = (dayData['exercises'] as List<dynamic>?) ?? [];

                    final bool hasDoneExercises = burned > 0 || exercises.isNotEmpty || (dayName == "Today" && dailyTracker.workoutLog.isNotEmpty);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                      title: Text(dayName, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      subtitle: Text("Burned: $burned kcal | Consumed: ${dayData['consumed']} kcal"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasDoneExercises ? Icons.check_circle : Icons.cancel,
                            color: hasDoneExercises ? Colors.green : Colors.red,
                            size: 22,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                        ],
                      ),
                      onTap: () => _showWeekdayExercisesSubWindow(context, dayData),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartView() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dailyTracker.weeklyProgressData.map((data) {
              int consumed = (data['consumed'] as num).toInt();
              int burned = (data['burned'] as num).toInt();
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: (consumed / 3000.0 * 100).clamp(10, 100),
                        decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 3),
                      Container(
                        width: 10,
                        height: (burned / 1000.0 * 100).clamp(10, 100),
                        decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(data['day'], style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.square, color: Colors.deepOrange, size: 12),
            const SizedBox(width: 4),
            Text("Consumed Total: ${dailyTracker.totalCalories} kcal", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 16),
            const Icon(Icons.square, color: Colors.green, size: 12),
            const SizedBox(width: 4),
            Text("Burned Total: ${dailyTracker.totalCaloriesBurned} kcal", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        )
      ],
    );
  }

  Widget _buildPieChartView() {
    final totalConsumed = dailyTracker.totalCalories;
    final totalBurned = dailyTracker.totalCaloriesBurned;
    final total = (totalConsumed + totalBurned) == 0 ? 1 : (totalConsumed + totalBurned);
    final consumedRatio = totalConsumed / total;
    final burnedRatio = totalBurned / total;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 140,
              width: 140,
              child: CustomPaint(
                painter: _PieChartPainter(consumedRatio: consumedRatio),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("${(consumedRatio * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                Text("${(burnedRatio * 100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.square, color: Colors.deepOrange, size: 12),
            const SizedBox(width: 4),
            Text("Consumed: $totalConsumed kcal", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(width: 16),
            const Icon(Icons.square, color: Colors.green, size: 12),
            const SizedBox(width: 4),
            Text("Burned: $totalBurned kcal", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        )
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final double consumedRatio;
  _PieChartPainter({required this.consumedRatio});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);

    final consumedPaint = Paint()
      ..color = Colors.deepOrange
      ..style = PaintingStyle.fill;

    final burnedPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.fill;

    double startAngle = -math.pi / 2;
    double consumedSweep = 2 * math.pi * consumedRatio;
    double burnedSweep = 2 * math.pi * (1 - consumedRatio);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      consumedSweep,
      true,
      consumedPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle + consumedSweep,
      burnedSweep,
      true,
      burnedPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.consumedRatio != consumedRatio;
}