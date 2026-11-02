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
            _buildNavigationCard(
              context,
              title: "1. Today's Progress",
              subtitle: "Activity, Steps & Macro Breakdown",
              icon: Icons.directions_walk,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage("1. Today's Progress", _buildTodaysProgressContent(context)),
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              title: "2. Progress Overview",
              subtitle: "Weekly Exercises & Chart Stats",
              icon: Icons.bar_chart,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage("2. Progress Overview", const ProgressOverviewSubPage()),
            ),
            const SizedBox(height: 12),

            const HomeNutritionAnalyzer(),
            const SizedBox(height: 12),

            _buildNavigationCard(
              context,
              title: "3. Daily Reminders & Hydration",
              subtitle: "Gym Notification Alarm & Creatine Water Tracker",
              icon: Icons.alarm,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage(
                "3. Daily Reminders & Hydration",
                _buildRemindersAndHydrationContent(context),
              ),
            ),
            const SizedBox(height: 12),
            _buildNavigationCard(
              context,
              title: "4. Today's Completed Exercises",
              subtitle: "Logged Sets & Workout History",
              icon: Icons.fitness_center,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onTap: () => _openSubPage("4. Today's Completed Exercises", _buildCompletedExercisesContent(context)),
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

  Widget _buildTodaysProgressContent(BuildContext context) {
    final netCalories = (dailyTracker.totalCalories - dailyTracker.totalCaloriesBurned).clamp(0, 10000);
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
      ],
    );
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

  Widget _buildCompletedExercisesContent(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return dailyTracker.workoutLog.isEmpty
        ? Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text("No exercises logged yet today.",
                    style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700])),
              ),
            ),
          )
        : Column(
            children: dailyTracker.workoutLog.map((item) {
              final workoutId = item['id'];
              List<SetLog> sets = (item['sets'] ?? <SetLog>[]) as List<SetLog>;

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
                      leading: const Icon(Icons.fitness_center, color: Colors.deepOrange),
                      title: Text("${item['muscle']} - ${item['exercise']}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                      subtitle: Text(item['details'] ?? "${sets.length} sets logged | Max Weight: ${item['maxWeight']} kg"),
                      trailing: Text(
                        "-${item['caloriesBurned']} kcal",
                        style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
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

class ProgressOverviewSubPage extends StatefulWidget {
  const ProgressOverviewSubPage({super.key});

  @override
  State<ProgressOverviewSubPage> createState() => _ProgressOverviewSubPageState();
}

class _ProgressOverviewSubPageState extends State<ProgressOverviewSubPage> {
  bool isPieChartMode = false;

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
                const Divider(height: 20),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dailyTracker.weeklyProgressData.length,
                  itemBuilder: (context, index) {
                    final dayData = dailyTracker.weeklyProgressData[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(dayData['day'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      subtitle: Text("Burned: ${dayData['burned']} kcal | Consumed: ${dayData['consumed']} kcal"),
                      trailing: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
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
    return SizedBox(
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
                    width: 8,
                    height: (consumed / 3000.0 * 100).clamp(10, 100),
                    decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 8,
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
    );
  }

  Widget _buildPieChartView() {
    final totalConsumed = dailyTracker.totalCalories;
    final totalBurned = dailyTracker.totalCaloriesBurned;
    final total = (totalConsumed + totalBurned) == 0 ? 1 : (totalConsumed + totalBurned);
    final consumedRatio = totalConsumed / total;

    return Column(
      children: [
        SizedBox(
          height: 140,
          width: 140,
          child: CustomPaint(
            painter: _PieChartPainter(consumedRatio: consumedRatio),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.square, color: Colors.deepOrange, size: 12),
            SizedBox(width: 4),
            Text("Consumed", style: TextStyle(fontSize: 12, color: Colors.grey)),
            SizedBox(width: 16),
            Icon(Icons.square, color: Colors.green, size: 12),
            SizedBox(width: 4),
            Text("Burned", style: TextStyle(fontSize: 12, color: Colors.grey)),
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

class HomeNutritionAnalyzer extends StatefulWidget {
  const HomeNutritionAnalyzer({super.key});

  @override
  State<HomeNutritionAnalyzer> createState() => _HomeNutritionAnalyzerState();
}

class _HomeNutritionAnalyzerState extends State<HomeNutritionAnalyzer> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _errorMessage;

  Future<void> _analyze() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await http.post(
        Uri.parse('https://backend-um5a.onrender.com/api/ai/nutrition'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'dish_name': text, 'quantity': '1 serving'}),
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'];
        setState(() {
          _result = data;
        });
      } else {
        setState(() {
          _errorMessage = "Server returned status: ${res.statusCode}";
        });
      }
    } catch (e) {
      debugPrint("Analysis error: $e");
      setState(() {
        _errorMessage = "Analysis error: $e";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                Text("Instant AI Nutrition Analyzer",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: primaryTextColor),
                    decoration: InputDecoration(
                      hintText: "e.g., 650g paneer or 4 boiled eggs",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange))
                      : const Icon(Icons.search, color: Colors.orange, size: 26),
                  onPressed: _loading ? null : _analyze,
                ),
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            if (_result != null) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Table(
                  border: TableBorder.symmetric(inside: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                  children: [
                    TableRow(children: [
                      const Padding(padding: EdgeInsets.all(8), child: Text("Food Item", style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(8), child: Text("${_result!['meal_name']}", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                    ]),
                    TableRow(children: [
                      const Padding(padding: EdgeInsets.all(8), child: Text("Calories", style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(8), child: Text("${_result!['calories']} kcal")),
                    ]),
                    TableRow(children: [
                      const Padding(padding: EdgeInsets.all(8), child: Text("Protein", style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(8), child: Text("${_result!['protein_g']}g")),
                    ]),
                    TableRow(children: [
                      const Padding(padding: EdgeInsets.all(8), child: Text("Carbs", style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(8), child: Text("${_result!['carbs_g']}g")),
                    ]),
                    TableRow(children: [
                      const Padding(padding: EdgeInsets.all(8), child: Text("Fat", style: TextStyle(fontWeight: FontWeight.bold))),
                      Padding(padding: const EdgeInsets.all(8), child: Text("${_result!['fat_g']}g")),
                    ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}