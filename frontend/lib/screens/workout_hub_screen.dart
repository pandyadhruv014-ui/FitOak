import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../state/daily_tracker_state.dart';
import '../widgets/custom_loading_switch.dart';

class WorkoutHubScreen extends StatelessWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout & Health Hub',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHubCard(
            context,
            title: '1. Strength Training',
            subtitle:
                'Select muscle groups, expanded exercises, sets, reps & weight',
            icon: Icons.fitness_center,
            destination: const ScaffoldPageWrapper(
              title: '1. Strength Training',
              child: StrengthMuscleSelectorScreen(),
            ),
          ),
          const SizedBox(height: 12),
          _buildHubCard(
            context,
            title: '2. Highest PR Records',
            subtitle:
                'Input and view personal records across all muscle groups',
            icon: Icons.emoji_events,
            destination: const ScaffoldPageWrapper(
              title: '2. Highest PR Records',
              child: PersonalRecordsScreen(),
            ),
          ),
          const SizedBox(height: 12),
          _buildHubCard(
            context,
            title: '3. Warmup/Stretching',
            subtitle: 'Before and after workout warmups & stretching routines',
            icon: Icons.self_improvement,
            destination: const ScaffoldPageWrapper(
              title: '3. Warmup/Stretching',
              child: WarmupRoutinesScreen(),
            ),
          ),
          const SizedBox(height: 12),
          _buildHubCard(
            context,
            title: '4. Cardio Sessions',
            subtitle: 'Treadmill, cycling & endurance tracking',
            icon: Icons.directions_run,
            destination: const ScaffoldPageWrapper(
              title: '4. Cardio Sessions',
              child: CardioSessionsScreen(),
            ),
          ),
          const SizedBox(height: 12),
          _buildHubCard(
            context,
            title: '5. BMI & Daily Calorie Target',
            subtitle:
                'Accurate BMI, goal-based calorie target & live Diet intake sync',
            icon: Icons.monitor_weight,
            destination: const ScaffoldPageWrapper(
              title: '5. BMI & Daily Calorie Target',
              child: BmiAndCalorieTargetScreen(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHubCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget destination,
  }) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor =
        theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700];

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(icon, color: Colors.deepOrange, size: 28),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: primaryTextColor)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle,
              style: TextStyle(fontSize: 12, color: secondaryTextColor)),
        ),
        trailing:
            Icon(Icons.arrow_forward_ios, size: 16, color: secondaryTextColor),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => destination),
          );
        },
      ),
    );
  }
}

class ScaffoldPageWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const ScaffoldPageWrapper(
      {super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

// ==========================================
// 5. ACCURATE BMI & GOAL CALORIE CALCULATOR (CONNECTED TO DIET SCREEN)
// ==========================================
class BmiAndCalorieTargetScreen extends StatefulWidget {
  const BmiAndCalorieTargetScreen({super.key});

  @override
  State<BmiAndCalorieTargetScreen> createState() =>
      _BmiAndCalorieTargetScreenState();
}

class _BmiAndCalorieTargetScreenState extends State<BmiAndCalorieTargetScreen> {
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  late TextEditingController _ageController;

  String _gender = 'Male';
  String _activityLevel = 'Moderate (3-5 days/week)';
  String _selectedGoal = 'Muscle Gain / Lean Bulk';

  final Map<String, double> _activityMultipliers = {
    'Sedentary (Desk job / little exercise)': 1.2,
    'Lightly Active (1-3 days/week)': 1.375,
    'Moderate (3-5 days/week)': 1.55,
    'Very Active (6-7 days/week)': 1.725,
    'Athlete (2x/day intense training)': 1.9,
  };

  final Map<String, int> _goalCalorieDelta = {
    'Weight Loss / Fat Loss (-500 kcal)': -500,
    'Lean Cut / Recomp (-250 kcal)': -250,
    'Maintain Weight (0 kcal)': 0,
    'Muscle Gain / Lean Bulk (+300 kcal)': 300,
    'Aggressive Bulking / Weight Gain (+500 kcal)': 500,
  };

  @override
  void initState() {
    super.initState();
    _heightController =
        TextEditingController(text: dailyTracker.heightCm.toStringAsFixed(1));
    _weightController =
        TextEditingController(text: dailyTracker.weightKg.toStringAsFixed(1));
    _ageController = TextEditingController(text: dailyTracker.age.toString());
    _gender =
        ['Male', 'Female'].contains(dailyTracker.gender) ? dailyTracker.gender : 'Male';
    if (_activityMultipliers.containsKey(dailyTracker.activityLevel)) {
      _activityLevel = dailyTracker.activityLevel;
    }
    if (_goalCalorieDelta.containsKey(dailyTracker.fitnessGoal)) {
      _selectedGoal = dailyTracker.fitnessGoal;
    }
    dailyTracker.fetchBackendMeals();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  double get _heightCm =>
      (double.tryParse(_heightController.text.trim()) ?? dailyTracker.heightCm)
          .clamp(80.0, 250.0);

  double get _weightKg =>
      (double.tryParse(_weightController.text.trim()) ?? dailyTracker.weightKg)
          .clamp(25.0, 300.0);

  int get _age =>
      (int.tryParse(_ageController.text.trim()) ?? dailyTracker.age)
          .clamp(12, 100);

  // Accurate BMI: kg / (m^2)
  double get _bmi {
    final hMeters = _heightCm / 100.0;
    return _weightKg / (hMeters * hMeters);
  }

  String get _bmiCategory {
    final b = _bmi;
    if (b < 18.5) return 'Underweight';
    if (b < 25.0) return 'Normal Weight';
    if (b < 30.0) return 'Overweight';
    return 'Obese';
  }

  Color get _bmiColor {
    final b = _bmi;
    if (b < 18.5) return Colors.blueAccent;
    if (b < 25.0) return Colors.green;
    if (b < 30.0) return Colors.orange;
    return Colors.redAccent;
  }

  double get _minHealthyWeight {
    final hMeters = _heightCm / 100.0;
    return 18.5 * hMeters * hMeters;
  }

  double get _maxHealthyWeight {
    final hMeters = _heightCm / 100.0;
    return 24.9 * hMeters * hMeters;
  }

  // Mifflin-St Jeor BMR Equation
  double get _bmr {
    final base = (10.0 * _weightKg) + (6.25 * _heightCm) - (5.0 * _age);
    return _gender == 'Male' ? base + 5.0 : base - 161.0;
  }

  // Maintenance Calories (TDEE)
  int get _tdee {
    final mult = _activityMultipliers[_activityLevel] ?? 1.55;
    return (_bmr * mult).round();
  }

  // Recommended Daily Calorie Target based on selected goal
  int get _recommendedCalories {
    final delta = _goalCalorieDelta[_selectedGoal] ?? 300;
    return (_tdee + delta).clamp(1200, 6500);
  }

  int get _recommendedProteinG {
    // 2.0g/kg for muscle gain/cut, 1.8g/kg for maintenance
    final factor = _selectedGoal.contains('Maintain') ? 1.8 : 2.1;
    return (_weightKg * factor).round();
  }

  int get _recommendedFatG {
    // 25% of target calories from healthy fats (9 kcal/g)
    return ((_recommendedCalories * 0.25) / 9.0).round();
  }

  int get _recommendedCarbsG {
    final remainingCals =
        _recommendedCalories - (_recommendedProteinG * 4) - (_recommendedFatG * 9);
    return (remainingCals / 4.0).clamp(50, 900).round();
  }

  Future<void> _saveTargetToDietTracker() async {
    await dailyTracker.updateCalorieAndBmiTargets(
      height: _heightCm,
      weight: _weightKg,
      userAge: _age,
      userGender: _gender,
      activity: _activityLevel,
      goal: _selectedGoal,
      calorieTarget: _recommendedCalories,
      proteinTarget: _recommendedProteinG,
      carbsTarget: _recommendedCarbsG,
      fatTarget: _recommendedFatG,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Saved $_recommendedCalories kcal/day goal & synced with Diet Screen!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return AnimatedBuilder(
      animation: dailyTracker,
      builder: (context, _) {
        final completedIntake = dailyTracker.totalCalories;
        final goalIntake = _recommendedCalories;
        final remainingKcal = goalIntake - completedIntake;
        final progress = (completedIntake / goalIntake).clamp(0.0, 1.0);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // LIVE DIET SCREEN CALORIE SYNC CARD
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.45)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.restaurant_menu,
                                  color: Colors.deepOrange, size: 20),
                              const SizedBox(width: 8),
                              Text("Today's Diet Calorie Progress",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: primaryTextColor)),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                size: 18, color: Colors.deepOrange),
                            tooltip: "Refresh Logged Meals",
                            onPressed: () => dailyTracker.fetchBackendMeals(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _miniMetric("Daily Goal", "$goalIntake kcal",
                              Colors.deepOrange),
                          _miniMetric("Completed (Diet)",
                              "$completedIntake kcal", Colors.green),
                          _miniMetric(
                            remainingKcal >= 0 ? "Remaining" : "Surplus",
                            "${remainingKcal.abs()} kcal",
                            remainingKcal >= 0
                                ? Colors.blueAccent
                                : Colors.amber,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 10,
                        backgroundColor:
                            Colors.deepOrange.withValues(alpha: 0.2),
                        color: remainingKcal >= 0
                            ? Colors.deepOrange
                            : Colors.green,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "${(progress * 100).toStringAsFixed(0)}% of daily target completed from ${dailyTracker.todayLog.length} logged meal(s)",
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // BODY METRICS & GOAL INPUTS
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Body Metrics & Fitness Goal",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryTextColor)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _heightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Height (cm)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Age (yrs)',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _gender,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: ['Male', 'Female']
                                  .map((g) => DropdownMenuItem(
                                      value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _gender = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _activityLevel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Weekly Activity Level',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _activityMultipliers.keys
                            .map((lvl) => DropdownMenuItem(
                                  value: lvl,
                                  child: Text(lvl,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _activityLevel = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedGoal,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Transformation Goal',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _goalCalorieDelta.keys
                            .map((g) => DropdownMenuItem(
                                  value: g,
                                  child: Text(g,
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedGoal = val);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ACCURATE BMI & METABOLIC BREAKDOWN CARD
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Accurate BMI Analysis",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: primaryTextColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _bmiColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _bmiCategory,
                              style: TextStyle(
                                  color: _bmiColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            _bmi.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                color: _bmiColor),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              "Healthy BMI Range: 18.5 – 24.9\nIdeal Weight for ${_heightCm.toStringAsFixed(0)} cm: ${_minHealthyWeight.toStringAsFixed(1)} – ${_maxHealthyWeight.toStringAsFixed(1)} kg",
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  height: 1.4),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text("Daily Calorie & Macro Suggestion",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: primaryTextColor)),
                      const SizedBox(height: 8),
                      Text(
                        "• Basal Metabolic Rate (BMR): ${_bmr.round()} kcal/day\n"
                        "• Maintenance Calories (TDEE): $_tdee kcal/day\n"
                        "• Recommended Target ($_selectedGoal): $_recommendedCalories kcal/day",
                        style: TextStyle(
                            fontSize: 13,
                            color: primaryTextColor,
                            height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _miniMetric("Protein", "${_recommendedProteinG}g",
                              Colors.blueAccent),
                          _miniMetric("Carbs", "${_recommendedCarbsG}g",
                              Colors.green),
                          _miniMetric(
                              "Fats", "${_recommendedFatG}g", Colors.amber),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange),
                          onPressed: _saveTargetToDietTracker,
                          icon: const Icon(Icons.check_circle,
                              color: Colors.white),
                          label: const Text(
                            "Apply Target & Sync with Diet Screen",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniMetric(String label, String val, Color color) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

// ==========================================
// STRENGTH TRAINING SECTION
// ==========================================
class StrengthMuscleSelectorScreen extends StatefulWidget {
  const StrengthMuscleSelectorScreen({super.key});

  @override
  State<StrengthMuscleSelectorScreen> createState() =>
      _StrengthMuscleSelectorScreenState();
}

class _StrengthMuscleSelectorScreenState
    extends State<StrengthMuscleSelectorScreen> {
  final Map<String, List<String>> muscleExerciseMap = {
    'Chest': [
      'Incline Barbell Bench Press',
      'Incline Dumbbell Press',
      'Pec Dec Flyes',
      'Cable Chest Flyes',
      'Flat Dumbbell Press',
      'Dips'
    ],
    'Back': [
      'Seated Rows Cable Machine',
      'Lat Pulldowns (Wide Grip)',
      'Lat Pulldowns (Close Grip)',
      'Lat Pulldowns (Underhand Grip)',
      'Barbell Bent-Over Rows',
      'Deadlifts',
      'Face Pulls'
    ],
    'Shoulders': [
      'Cable Lateral Raises',
      'Cable Front Raises',
      'Face Pulls',
      'Overhead Shoulder Press',
      'Arnold Press',
      'Rear Delt Flyes'
    ],
    'Biceps': [
      'Cable Bicep Curls',
      'Rope Curls',
      'Wide Grip Cable Rod Curls',
      'Barbell Curls',
      'Hammer Curls',
      'Preacher Curls'
    ],
    'Triceps': [
      'Triceps Rod Pushdown',
      'Single Arm Triceps Pushdown',
      'Triceps Rope Pushdowns',
      'Skull Crushers',
      'Overhead Extensions'
    ],
    'Legs': [
      'Bulgarian Split Squat',
      'Hack Squat',
      'Barbell Squats',
      'Leg Press',
      'Romanian Deadlifts',
      'Leg Extensions',
      'Hamstring Curls'
    ],
    'Abs': [
      'Cable Crunches',
      'Hanging Leg Raises',
      'Plank Holds',
      'Russian Twists'
    ],
  };

  final Map<String, List<String>> muscleAssetCandidates = {
    'Chest': ['assets/icons/chest.png', 'assets/chest.png'],
    'Back': ['assets/icons/back.png', 'assets/back.png'],
    'Shoulders': ['assets/icons/shoulders.png', 'assets/shoulders.png'],
    'Biceps': ['assets/icons/biceps.png', 'assets/biceps.png'],
    'Triceps': ['assets/icons/triceps.png', 'assets/triceps.png'],
    'Legs': ['assets/icons/legs.png', 'assets/legs.png'],
    'Abs': ['assets/icons/abs.png', 'assets/abs.png'],
  };

  void _openMuscleSubWindow(String muscle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MuscleWorkoutSubWindow(
          muscleName: muscle,
          exercises: muscleExerciseMap[muscle] ?? [],
          assetPaths: muscleAssetCandidates[muscle] ?? [],
          allowAdvancedSets: muscle != 'Abs',
        ),
      ),
    );
  }

  Widget _buildMuscleIcon(List<String> paths) {
    return _tryLoadImage(paths, 0);
  }

  Widget _tryLoadImage(List<String> paths, int index) {
    if (index >= paths.length) {
      return const Icon(Icons.fitness_center,
          color: Colors.deepOrange, size: 34);
    }
    return Image.asset(
      paths[index],
      width: 52,
      height: 52,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _tryLoadImage(paths, index + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor =
        theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700];

    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: muscleExerciseMap.keys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final muscle = muscleExerciseMap.keys.elementAt(index);
        final exercises = muscleExerciseMap[muscle]!;
        final candidatePaths = muscleAssetCandidates[muscle] ?? [];

        return Card(
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: SizedBox(
              width: 52,
              height: 52,
              child: Center(
                child: _buildMuscleIcon(candidatePaths),
              ),
            ),
            title: Text(
              muscle,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: primaryTextColor),
            ),
            subtitle: Text(
              "${exercises.length} Exercises available",
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: secondaryTextColor),
            onTap: () => _openMuscleSubWindow(muscle),
          ),
        );
      },
    );
  }
}

// ==========================================
// DEDICATED MUSCLE SUB-WINDOW PAGE
// ==========================================
class MuscleWorkoutSubWindow extends StatefulWidget {
  final String muscleName;
  final List<String> exercises;
  final List<String> assetPaths;
  final bool allowAdvancedSets;

  const MuscleWorkoutSubWindow({
    super.key,
    required this.muscleName,
    required this.exercises,
    required this.assetPaths,
    required this.allowAdvancedSets,
  });

  @override
  State<MuscleWorkoutSubWindow> createState() => _MuscleWorkoutSubWindowState();
}

class _MuscleWorkoutSubWindowState extends State<MuscleWorkoutSubWindow> {
  late String selectedExercise;
  String? pairedSuperSetExercise;

  bool isSuperSetMode = false;
  bool isDropSetMode = false;

  late Set<int> selectedBuddyIds;

  List<SetLog> currentSets = [
    SetLog(setNumber: 1, reps: 12, weight: 20.0),
    SetLog(setNumber: 2, reps: 10, weight: 25.0),
  ];

  @override
  void initState() {
    super.initState();
    selectedExercise = widget.exercises.isNotEmpty ? widget.exercises.first : '';
    selectedBuddyIds = dailyTracker.gymBuddiesExcludingMe
        .map((b) => b['user_id'] as int)
        .toSet();
  }

  void _addSet() {
    setState(() {
      int nextSetNum = currentSets.length + 1;
      double lastWeight =
          currentSets.isNotEmpty ? currentSets.last.weight : 20.0;
      int lastReps = currentSets.isNotEmpty ? currentSets.last.reps : 10;

      if (isDropSetMode) {
        lastWeight = double.parse((lastWeight * 0.80).toStringAsFixed(1));
      }

      currentSets.add(SetLog(
        setNumber: nextSetNum,
        reps: lastReps,
        weight: lastWeight,
        isSpecialSet: isDropSetMode,
      ));
    });
  }

  void _removeSet(int index) {
    if (currentSets.length > 1) {
      setState(() {
        currentSets.removeAt(index);
        for (int i = 0; i < currentSets.length; i++) {
          currentSets[i].setNumber = i + 1;
        }
      });
    }
  }

  Future<void> _logWorkoutSession() async {
    String logName = selectedExercise;
    if (isSuperSetMode && pairedSuperSetExercise != null) {
      logName = "$selectedExercise + $pairedSuperSetExercise (Super Set)";
    } else if (isDropSetMode) {
      logName = "$selectedExercise (Drop Set)";
    }

    final messenger = ScaffoldMessenger.of(context);
    final buddiesCount = selectedBuddyIds.length;

    await dailyTracker.logExerciseWithSets(
      muscle: widget.muscleName,
      exerciseName: logName,
      sets: currentSets,
      buddyUserIds: selectedBuddyIds.toList(),
    );

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          buddiesCount > 0
              ? 'Logged $logName for you + $buddiesCount gym buddy(s)!'
              : 'Logged $logName to Today\'s Workouts!',
        ),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final buddies = dailyTracker.gymBuddiesExcludingMe;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Image.asset(
                widget.assetPaths.isNotEmpty ? widget.assetPaths[0] : '',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Image.asset(
                  widget.assetPaths.length > 1 ? widget.assetPaths[1] : '',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center,
                      color: Colors.deepOrange, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "${widget.muscleName} Workouts",
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Select Primary Exercise",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: primaryTextColor)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedExercise,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(), isDense: true),
                      items: widget.exercises
                          .map((ex) => DropdownMenuItem(
                                value: ex,
                                child: Text(ex,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1),
                              ))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedExercise = val);
                      },
                    ),
                    if (widget.allowAdvancedSets) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text("Super Set Mode",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryTextColor)),
                          ),
                          CustomLoadingSwitch(
                            value: isSuperSetMode,
                            onChanged: (val) {
                              setState(() {
                                isSuperSetMode = val;
                                if (val) isDropSetMode = false;
                              });
                            },
                          ),
                        ],
                      ),
                      if (isSuperSetMode) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          hint: const Text("Select Paired Exercise",
                              overflow: TextOverflow.ellipsis),
                          decoration: const InputDecoration(
                              labelText: 'Paired Super Set Exercise',
                              border: OutlineInputBorder(),
                              isDense: true),
                          items: widget.exercises
                              .where((e) => e != selectedExercise)
                              .map((ex) => DropdownMenuItem(
                                    value: ex,
                                    child: Text(ex,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => pairedSuperSetExercise = val),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text("Drop Set Mode (-20% Auto-weight)",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryTextColor)),
                          ),
                          CustomLoadingSwitch(
                            value: isDropSetMode,
                            onChanged: (val) {
                              setState(() {
                                isDropSetMode = val;
                                if (val) isSuperSetMode = false;
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text("Sets Breakdown",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: primaryTextColor)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: currentSets.length,
              itemBuilder: (ctx, index) {
                final setItem = currentSets[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.deepOrange,
                          child: Text("${setItem.setNumber}",
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            key: Key('reps_${index}_${setItem.reps}'),
                            initialValue: "${setItem.reps}",
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Reps',
                                border: OutlineInputBorder(),
                                isDense: true),
                            onChanged: (val) => setItem.reps =
                                int.tryParse(val) ?? setItem.reps,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: Key('weight_${index}_${setItem.weight}'),
                            initialValue: "${setItem.weight}",
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Weight (kg)',
                                border: OutlineInputBorder(),
                                isDense: true),
                            onChanged: (val) => setItem.weight =
                                double.tryParse(val) ?? setItem.weight,
                          ),
                        ),
                        const SizedBox(width: 6),
                        CustomLoadingSwitch(
                          value: setItem.isSpecialSet,
                          onChanged: (val) =>
                              setState(() => setItem.isSpecialSet = val),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle,
                              color: Colors.redAccent),
                          onPressed: () => _removeSet(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.deepOrange),
                  minimumSize: const Size.fromHeight(42)),
              onPressed: _addSet,
              icon: const Icon(Icons.add, color: Colors.deepOrange),
              label: Text(
                isDropSetMode ? "Add Drop Set (-20% Weight)" : "Add Another Set",
                style: const TextStyle(color: Colors.deepOrange),
              ),
            ),
            if (dailyTracker.activeGymGroup != null) ...[
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.groups,
                              color: Colors.deepOrange, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Co-Log with ${dailyTracker.activeGymGroup?['group_name'] ?? 'Gym Squad'}",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: primaryTextColor),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh,
                                size: 18, color: Colors.deepOrange),
                            tooltip: "Refresh Squad Members",
                            onPressed: () async {
                              await dailyTracker.fetchMyGymGroup();
                              if (mounted) {
                                setState(() {
                                  selectedBuddyIds = dailyTracker
                                      .gymBuddiesExcludingMe
                                      .map((b) => b['user_id'] as int)
                                      .toSet();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      if (buddies.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 4.0),
                          child: Text(
                            "No other buddies in your squad yet. Have a buddy join with your entry pass, then tap refresh.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        )
                      else ...[
                        const Text(
                          "Checked buddies also get this exercise logged automatically:",
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        const SizedBox(height: 6),
                        ...buddies.map((buddy) {
                          final bid = buddy['user_id'] as int;
                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            activeColor: Colors.deepOrange,
                            title: Text(buddy['user_name'] ?? 'Buddy',
                                style: TextStyle(color: primaryTextColor)),
                            value: selectedBuddyIds.contains(bid),
                            onChanged: (checked) {
                              setState(() {
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
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  minimumSize: const Size.fromHeight(48)),
              onPressed: _logWorkoutSession,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Log Exercise Session',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// HIGHEST PR RECORDS
// ==========================================
class PersonalRecordsScreen extends StatefulWidget {
  const PersonalRecordsScreen({super.key});

  @override
  State<PersonalRecordsScreen> createState() => _PersonalRecordsScreenState();
}

class _PersonalRecordsScreenState extends State<PersonalRecordsScreen> {
  final TextEditingController _weightController = TextEditingController();
  String _selectedMuscle = 'Chest';
  String _selectedExercise = 'Incline Dumbbell Press';

  final Map<String, List<String>> _exercises = {
    'Chest': [
      'Incline Dumbbell Press',
      'Pec Dec Flyes',
      'Cable Chest Flyes',
      'Bench Press'
    ],
    'Back': ['Seated Rows Cable Machine', 'Lat Pulldowns', 'Deadlift'],
    'Legs': ['Bulgarian Split Squat', 'Hack Squat', 'Barbell Squat'],
    'Shoulders': ['Cable Lateral Raises', 'Cable Front Raises', 'Face Pulls'],
    'Biceps': [
      'Cable Bicep Curls',
      'Rope Curls',
      'Wide Grip Cable Rod Curls'
    ],
    'Triceps': [
      'Triceps Rod Pushdown',
      'Single Arm Triceps Pushdown',
      'Skull Crushers'
    ],
    'Abs': ['Cable Crunches', 'Hanging Leg Raises'],
  };

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  void _inputPR() {
    final weight = double.tryParse(_weightController.text.trim());
    if (weight != null && weight > 0) {
      dailyTracker.updateOrAddPR(_selectedMuscle, _selectedExercise, weight);
      _weightController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Updated PR for $_selectedExercise to $weight kg!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return AnimatedBuilder(
      animation: dailyTracker,
      builder: (context, _) {
        final prs = dailyTracker.personalRecords;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Input / Update Personal Record (PR)",
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
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedMuscle,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Muscle',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                              ),
                              items: _exercises.keys
                                  .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m,
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedMuscle = val;
                                    _selectedExercise = _exercises[val]!.first;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedExercise,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Exercise',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                              ),
                              items: (_exercises[_selectedMuscle] ?? [])
                                  .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Text(e,
                                          overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedExercise = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Highest Weight Lifted (kg)',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber,
                            minimumSize: const Size.fromHeight(45)),
                        onPressed: _inputPR,
                        icon:
                            const Icon(Icons.emoji_events, color: Colors.black),
                        label: const Text('Save Personal Record',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Text("Highest PR Records Stored",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryTextColor)),
              const SizedBox(height: 10),
              prs.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(
                            child: Text("No PR records stored yet.",
                                style: TextStyle(
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.grey
                                        : Colors.grey[700]))),
                      ),
                    )
                  : Column(
                      children: prs.entries.map((muscleEntry) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ExpansionTile(
                            leading: const Icon(Icons.emoji_events,
                                color: Colors.amber),
                            title: Text("${muscleEntry.key} PRs",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: primaryTextColor)),
                            children: muscleEntry.value.entries.map((exEntry) {
                              return ListTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        exEntry.key,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style:
                                            TextStyle(color: primaryTextColor),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${exEntry.value} kg",
                                      style: const TextStyle(
                                          color: Colors.deepOrange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// WARMUP/STRETCHING
// ==========================================
class WarmupRoutinesScreen extends StatefulWidget {
  const WarmupRoutinesScreen({super.key});

  @override
  State<WarmupRoutinesScreen> createState() => _WarmupRoutinesScreenState();
}

class _WarmupRoutinesScreenState extends State<WarmupRoutinesScreen> {
  String _selectedMuscle = 'Chest & Shoulders';

  final Map<String, Map<String, List<String>>> _warmupData = {
    'Chest & Shoulders': {
      'Before Workout (Dynamic Warmup)': [
        'Arm Circles (15 forward, 15 backward)',
        'Band Dislocates (12 reps)',
        'Dynamic Chest Hugs (15 reps)',
        'Light Cable Face Pulls (15 reps)'
      ],
      'After Workout (Static Stretching)': [
        'Doorway Chest Stretch (30s hold per side)',
        'Cross-Body Shoulder Stretch (30s hold)',
        'Overhead Triceps Stretch (30s hold)'
      ],
    },
    'Back & Core': {
      'Before Workout (Dynamic Warmup)': [
        'Cat-Cow Stretch (12 reps)',
        'Thoracic Spine Rotations (10 reps/side)',
        'Bodyweight Good Mornings (15 reps)',
        'Inverted Bodyweight Rows (10 reps)'
      ],
      'After Workout (Static Stretching)': [
        'Child\'s Pose Stretch (45s hold)',
        'Cobra Pose Stretch (30s hold)',
        'Hanging Lat Stretch (30s hold)'
      ],
    },
    'Legs & Hips': {
      'Before Workout (Dynamic Warmup)': [
        'Leg Swings (15 forward/backward & lateral)',
        'Bodyweight Squats (15 reps)',
        'Walking Hip Openers / World\'s Greatest Stretch (10 reps)',
        'Bodyweight Glute Bridges (15 reps)'
      ],
      'After Workout (Static Stretching)': [
        'Standing Quadriceps Stretch (30s/leg)',
        'Seated Hamstring Stretch (40s hold)',
        'Pigeon Pose Hip Opener (30s/side)'
      ],
    },
  };

  @override
  Widget build(BuildContext context) {
    final routines = _warmupData[_selectedMuscle] ?? {};
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Target Muscle Group",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8.0,
            children: _warmupData.keys.map((group) {
              final isSelected = _selectedMuscle == group;
              return ChoiceChip(
                label: Text(group),
                selected: isSelected,
                selectedColor: Colors.deepOrange,
                onSelected: (val) {
                  if (val) setState(() => _selectedMuscle = group);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.play_circle_fill, color: Colors.amber),
                      SizedBox(width: 8),
                      Text("Before Workout Warmup",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber)),
                    ],
                  ),
                  const Divider(),
                  ...(routines['Before Workout (Dynamic Warmup)'] ?? [])
                      .map((ex) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 16, color: Colors.deepOrange),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(ex,
                                        style: TextStyle(
                                            color: primaryTextColor))),
                              ],
                            ),
                          )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.stop_circle, color: Colors.teal),
                      SizedBox(width: 8),
                      Text("After Workout Cooldowns",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal)),
                    ],
                  ),
                  const Divider(),
                  ...(routines['After Workout (Static Stretching)'] ?? [])
                      .map((ex) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    size: 16, color: Colors.teal),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(ex,
                                        style: TextStyle(
                                            color: primaryTextColor))),
                              ],
                            ),
                          )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// CARDIO SESSIONS (AI-POWERED)
// ==========================================
class CardioSessionsScreen extends StatefulWidget {
  const CardioSessionsScreen({super.key});

  @override
  State<CardioSessionsScreen> createState() => _CardioSessionsScreenState();
}

class _CardioSessionsScreenState extends State<CardioSessionsScreen> {
  String _cardioType = 'Treadmill Running';
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _speedController = TextEditingController();
  final TextEditingController _inclineController = TextEditingController();

  bool _isCalculating = false;

  @override
  void dispose() {
    _durationController.dispose();
    _speedController.dispose();
    _inclineController.dispose();
    super.dispose();
  }

  Future<void> _calculateAndLogCardio() async {
    final duration = int.tryParse(_durationController.text.trim()) ?? 0;
    final speed = double.tryParse(_speedController.text.trim()) ?? 0.0;
    final incline = double.tryParse(_inclineController.text.trim()) ?? 0.0;

    if (duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid duration!')));
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final prompt =
          "Calculate calories burned for $_cardioType session: duration $duration mins, speed $speed km/h, incline $incline%. Return JSON strictly in format: {\"calories\": 0, \"distance_km\": 0.0}";

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/ai/chat'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(const Duration(seconds: 50));

      int cals = (duration * 8.5).toInt();
      double dist = (speed * (duration / 60.0));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawText = data['response'] ?? '';
        rawText =
            rawText.replaceAll("```json", "").replaceAll("```", "").trim();
        try {
          final jsonResult = jsonDecode(rawText);
          cals = jsonResult['calories'] ?? cals;
          dist = (jsonResult['distance_km'] as num).toDouble();
        } catch (_) {}
      }

      dailyTracker.logCardioSession(_cardioType, duration, dist, cals);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Logged $_cardioType: $cals kcal burned ($dist km)!')),
      );

      _durationController.clear();
      _speedController.clear();
      _inclineController.clear();
    } catch (_) {
      int fallbackCals = (duration * 8).toInt();
      double fallbackDist = (speed * (duration / 60.0));
      dailyTracker.logCardioSession(
          _cardioType, duration, fallbackDist, fallbackCals);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Logged $_cardioType (Offline estimate): $fallbackCals kcal!')),
      );
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Cardio Endurance Tracker",
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
                  DropdownButtonFormField<String>(
                    initialValue: _cardioType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Cardio Mode', border: OutlineInputBorder()),
                    items: [
                      'Treadmill Running',
                      'Outdoor Cycling',
                      'Rowing Machine',
                      'Elliptical Trainer',
                      'Stair Master'
                    ]
                        .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _cardioType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Duration (Minutes)',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _speedController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Avg Speed (km/h)',
                              border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _inclineController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Incline Level / Resistance',
                              border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        minimumSize: const Size.fromHeight(45)),
                    onPressed: _isCalculating ? null : _calculateAndLogCardio,
                    child: _isCalculating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Calculate Calories & Log Session',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
