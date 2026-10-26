import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../state/daily_tracker_state.dart';
import 'trackers_screen.dart';

class WorkoutHubScreen extends StatelessWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout & Health Hub')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text("Select Hub Category", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildHubCard(
            context,
            title: 'Strength Training',
            subtitle: 'Select muscle groups, expanded exercises, sets, reps & weight',
            icon: Icons.fitness_center,
            color: Colors.deepOrange,
            destination: const ScaffoldPageWrapper(
              title: 'Strength Training',
              child: StrengthMuscleSelectorScreen(),
            ),
          ),
          _buildHubCard(
            context,
            title: 'Highest PR Records',
            subtitle: 'Input and view personal records across all muscle groups',
            icon: Icons.emoji_events,
            color: Colors.amber,
            destination: const ScaffoldPageWrapper(
              title: 'Highest PR Records',
              child: PersonalRecordsScreen(),
            ),
          ),
          _buildHubCard(
            context,
            title: 'Trackers (Nutrition & Sensors)',
            subtitle: 'Gemini AI nutrition analysis & built-in motion sensor tracking',
            icon: Icons.track_changes,
            color: Colors.blue,
            destination: const ScaffoldPageWrapper(
              title: 'Health & Nutrition Trackers',
              child: TrackersTabScreen(),
            ),
          ),
          _buildHubCard(
            context,
            title: 'Warmup/Stretching',
            subtitle: 'Before and after workout warmups & stretching routines',
            icon: Icons.self_improvement,
            color: Colors.purple,
            destination: const ScaffoldPageWrapper(
              title: 'Warmup/Stretching',
              child: WarmupRoutinesScreen(),
            ),
          ),
          _buildHubCard(
            context,
            title: 'AI Cardio Sessions',
            subtitle: 'Treadmill, cycling & endurance tracking with Gemini AI calculations',
            icon: Icons.directions_run,
            color: Colors.teal,
            destination: const ScaffoldPageWrapper(
              title: 'Cardio Sessions',
              child: CardioSessionsScreen(),
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
    required Color color,
    required Widget destination,
  }) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(50),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
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

  const ScaffoldPageWrapper({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: child,
    );
  }
}

// ==========================================
// STRENGTH TRAINING SECTION
// ==========================================
class StrengthMuscleSelectorScreen extends StatefulWidget {
  const StrengthMuscleSelectorScreen({super.key});

  @override
  State<StrengthMuscleSelectorScreen> createState() => _StrengthMuscleSelectorScreenState();
}

class _StrengthMuscleSelectorScreenState extends State<StrengthMuscleSelectorScreen> {
  final Map<String, List<String>> muscleExerciseMap = {
    'Chest': ['Incline Barbell Bench Press', 'Incline Dumbbell Press', 'Pec Dec Flyes', 'Cable Chest Flyes', 'Flat Dumbbell Press', 'Dips'],
    'Back': ['Seated Rows Cable Machine', 'Lat Pulldowns (Wide Grip)', 'Lat Pulldowns (Close Grip)', 'Lat Pulldowns (Underhand Grip)', 'Barbell Bent-Over Rows', 'Deadlifts', 'Face Pulls'],
    'Shoulders': ['Cable Lateral Raises', 'Cable Front Raises', 'Face Pulls', 'Overhead Shoulder Press', 'Arnold Press', 'Rear Delt Flyes'],
    'Biceps': ['Cable Bicep Curls', 'Rope Curls', 'Wide Grip Cable Rod Curls', 'Barbell Curls', 'Hammer Curls', 'Preacher Curls'],
    'Triceps': ['Triceps Rod Pushdown', 'Single Arm Triceps Pushdown', 'Triceps Rope Pushdowns', 'Skull Crushers', 'Overhead Extensions'],
    'Legs': ['Bulgarian Split Squat', 'Hack Squat', 'Barbell Squats', 'Leg Press', 'Romanian Deadlifts', 'Leg Extensions', 'Hamstring Curls'],
    'Abs': ['Cable Crunches', 'Hanging Leg Raises', 'Plank Holds', 'Russian Twists'],
  };

  String? selectedMuscle = 'Chest';
  String? selectedExercise;

  List<SetLog> currentSets = [
    SetLog(setNumber: 1, reps: 12, weight: 20.0),
    SetLog(setNumber: 2, reps: 10, weight: 25.0),
    SetLog(setNumber: 3, reps: 8, weight: 30.0),
  ];

  @override
  void initState() {
    super.initState();
    selectedExercise = muscleExerciseMap['Chest']!.first;
  }

  void _addSet() {
    setState(() {
      int nextSetNum = currentSets.length + 1;
      double lastWeight = currentSets.isNotEmpty ? currentSets.last.weight : 20.0;
      int lastReps = currentSets.isNotEmpty ? currentSets.last.reps : 10;
      currentSets.add(SetLog(setNumber: nextSetNum, reps: lastReps, weight: lastWeight));
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

  void _logExercise() {
    if (selectedMuscle == null || selectedExercise == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a muscle and exercise first!')),
      );
      return;
    }

    dailyTracker.logExerciseWithSets(
      muscle: selectedMuscle!,
      exerciseName: selectedExercise!,
      sets: currentSets,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged $selectedExercise to Today\'s Workouts!')),
    );

    setState(() {
      currentSets = [
        SetLog(setNumber: 1, reps: 12, weight: 20.0),
        SetLog(setNumber: 2, reps: 10, weight: 25.0),
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Choose Muscle Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.1,
            ),
            itemCount: muscleExerciseMap.keys.length,
            itemBuilder: (context, index) {
              final muscle = muscleExerciseMap.keys.elementAt(index);
              final isSelected = selectedMuscle == muscle;
              return InkWell(
                onTap: () {
                  setState(() {
                    selectedMuscle = muscle;
                    selectedExercise = muscleExerciseMap[muscle]!.first;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepOrange : const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fitness_center, color: isSelected ? Colors.white : Colors.deepOrange),
                      const SizedBox(height: 6),
                      Text(
                        muscle,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          if (selectedMuscle != null) ...[
            Text("$selectedMuscle Exercises", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              initialValue: selectedExercise,
              decoration: const InputDecoration(labelText: 'Choose Exercise', border: OutlineInputBorder()),
              items: muscleExerciseMap[selectedMuscle!]!
                  .map((ex) => DropdownMenuItem(value: ex, child: Text(ex)))
                  .toList(),
              onChanged: (val) => setState(() => selectedExercise = val),
            ),
            const SizedBox(height: 15),

            if (selectedExercise != null) ...[
              const Text("Customizable Sets Breakdown", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),

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
                            child: Text("${setItem.setNumber}", style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              initialValue: "${setItem.reps}",
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Reps', border: OutlineInputBorder(), isDense: true),
                              onChanged: (val) => setItem.reps = int.tryParse(val) ?? setItem.reps,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              initialValue: "${setItem.weight}",
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder(), isDense: true),
                              onChanged: (val) => setItem.weight = double.tryParse(val) ?? setItem.weight,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.flash_on, color: setItem.isSpecialSet ? Colors.amber : Colors.grey),
                            onPressed: () => setState(() => setItem.isSpecialSet = !setItem.isSpecialSet),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                            onPressed: () => _removeSet(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.deepOrange), minimumSize: const Size.fromHeight(42)),
                onPressed: _addSet,
                icon: const Icon(Icons.add, color: Colors.deepOrange),
                label: const Text("Add Another Set", style: TextStyle(color: Colors.deepOrange)),
              ),
              const SizedBox(height: 15),

              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, minimumSize: const Size.fromHeight(48)),
                onPressed: _logExercise,
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text('Log Exercise Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ]
          ],
        ],
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
    'Chest': ['Incline Dumbbell Press', 'Pec Dec Flyes', 'Cable Chest Flyes', 'Bench Press'],
    'Back': ['Seated Rows Cable Machine', 'Lat Pulldowns', 'Deadlift'],
    'Legs': ['Bulgarian Split Squat', 'Hack Squat', 'Barbell Squat'],
    'Shoulders': ['Cable Lateral Raises', 'Cable Front Raises', 'Face Pulls'],
    'Biceps': ['Cable Bicep Curls', 'Rope Curls', 'Wide Grip Cable Rod Curls'],
    'Triceps': ['Triceps Rod Pushdown', 'Single Arm Triceps Pushdown', 'Skull Crushers'],
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
        SnackBar(content: Text('Updated PR for $_selectedExercise to $weight kg!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dailyTracker,
      builder: (context, _) {
        final prs = dailyTracker.personalRecords;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Input / Update Personal Record (PR)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              Card(
                color: const Color(0xFF1E1E1E),
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: _exercises.keys.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
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
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              ),
                              items: (_exercises[_selectedMuscle] ?? []).map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedExercise = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Highest Weight Lifted (kg)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size.fromHeight(45)),
                        onPressed: _inputPR,
                        icon: const Icon(Icons.emoji_events, color: Colors.black),
                        label: const Text('Save Personal Record', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              const Text("Highest PR Records Stored", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              prs.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text("No PR records stored yet.")),
                      ),
                    )
                  : Column(
                      children: prs.entries.map((muscleEntry) {
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ExpansionTile(
                            leading: const Icon(Icons.emoji_events, color: Colors.amber),
                            title: Text("${muscleEntry.key} PRs", style: const TextStyle(fontWeight: FontWeight.bold)),
                            children: muscleEntry.value.entries.map((exEntry) {
                              return ListTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        exEntry.key,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "${exEntry.value} kg",
                                      style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select Target Muscle Group", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.play_circle_fill, color: Colors.amber),
                      SizedBox(width: 8),
                      Text("Before Workout Warmup", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ],
                  ),
                  const Divider(),
                  ...(routines['Before Workout (Dynamic Warmup)'] ?? []).map((ex) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: Colors.deepOrange),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ex)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ),
          const SizedBox(height: 15),

          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.stop_circle, color: Colors.teal),
                      SizedBox(width: 8),
                      Text("After Workout Cooldowns", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ],
                  ),
                  const Divider(),
                  ...(routines['After Workout (Static Stretching)'] ?? []).map((ex) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ex)),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid duration!')));
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final prompt = "Calculate calories burned for $_cardioType session: duration $duration mins, speed $speed km/h, incline $incline%. Return JSON strictly in format: {\"calories\": 0, \"distance_km\": 0.0}";

      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/chat'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'prompt': prompt}),
      ).timeout(const Duration(seconds: 25));

      int cals = (duration * 8.5).toInt();
      double dist = (speed * (duration / 60.0));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String rawText = data['response'] ?? '';
        rawText = rawText.replaceAll("```json", "").replaceAll("```", "").trim();
        try {
          final jsonResult = jsonDecode(rawText);
          cals = jsonResult['calories'] ?? cals;
          dist = (jsonResult['distance_km'] as num).toDouble();
        } catch (_) {}
      }

      dailyTracker.logCardioSession(_cardioType, duration, dist, cals);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged $_cardioType: $cals kcal burned ($dist km)!')),
      );

      _durationController.clear();
      _speedController.clear();
      _inclineController.clear();
    } catch (_) {
      int fallbackCals = (duration * 8).toInt();
      double fallbackDist = (speed * (duration / 60.0));
      dailyTracker.logCardioSession(_cardioType, duration, fallbackDist, fallbackCals);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logged $_cardioType (Offline estimate): $fallbackCals kcal!')),
      );
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("AI-Powered Cardio Endurance Tracker", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Card(
            color: const Color(0xFF1E1E1E),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _cardioType,
                    decoration: const InputDecoration(labelText: 'Cardio Mode', border: OutlineInputBorder()),
                    items: ['Treadmill Running', 'Outdoor Cycling', 'Rowing Machine', 'Elliptical Trainer', 'Stair Master']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _cardioType = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Duration (Minutes)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _speedController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Avg Speed (km/h)', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _inclineController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Incline Level / Resistance', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size.fromHeight(45)),
                    onPressed: _isCalculating ? null : _calculateAndLogCardio,
                    child: _isCalculating
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Calculate Calories & Log Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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