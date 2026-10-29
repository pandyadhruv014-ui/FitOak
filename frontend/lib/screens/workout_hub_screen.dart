import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import '../state/daily_tracker_state.dart';
import '../widgets/custom_loading_switch.dart';
import 'trackers_screen.dart';

class WorkoutHubScreen extends StatelessWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout & Health Hub', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildHubCard(
            context,
            title: '1. Strength Training',
            subtitle: 'Select muscle groups, expanded exercises, sets, reps & weight',
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
            subtitle: 'Input and view personal records across all muscle groups',
            icon: Icons.emoji_events,
            destination: const ScaffoldPageWrapper(
              title: '2. Highest PR Records',
              child: PersonalRecordsScreen(),
            ),
          ),
          const SizedBox(height: 12),
          _buildHubCard(
            context,
            title: '3. Trackers (Nutrition & Sensors)',
            subtitle: 'Gemini AI nutrition analysis & built-in motion sensor tracking',
            icon: Icons.track_changes,
            destination: const ScaffoldPageWrapper(
              title: '3. Health & Nutrition Trackers',
              child: TrackersTabScreen(),
            ),
          ),
          const SizedBox(height: 12),
          _buildHubCard(
            context,
            title: '4. Warmup/Stretching',
            subtitle: 'Before and after workout warmups & stretching routines',
            icon: Icons.self_improvement,
            destination: const ScaffoldPageWrapper(
              title: '4. Warmup/Stretching',
              child: WarmupRoutinesScreen(),
            ),
          ),
          const SizedBox(height: 12),
          _buildHubCard(
            context,
            title: '5. AI Cardio Sessions',
            subtitle: 'Treadmill, cycling & endurance tracking with Gemini AI calculations',
            icon: Icons.directions_run,
            destination: const ScaffoldPageWrapper(
              title: '5. Cardio Sessions',
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
    required Widget destination,
  }) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700];

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: Icon(icon, color: Colors.deepOrange, size: 28),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(subtitle, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: secondaryTextColor),
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
      return const Icon(Icons.fitness_center, color: Colors.deepOrange, size: 34);
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
    final secondaryTextColor = theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700];

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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: SizedBox(
              width: 52,
              height: 52,
              child: Center(
                child: _buildMuscleIcon(candidatePaths),
              ),
            ),
            title: Text(
              muscle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryTextColor),
            ),
            subtitle: Text(
              "${exercises.length} Exercises available",
              style: TextStyle(fontSize: 12, color: secondaryTextColor),
            ),
            trailing: Icon(Icons.arrow_forward_ios, size: 16, color: secondaryTextColor),
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

  List<SetLog> currentSets = [
    SetLog(setNumber: 1, reps: 12, weight: 20.0),
    SetLog(setNumber: 2, reps: 10, weight: 25.0),
  ];

  @override
  void initState() {
    super.initState();
    selectedExercise = widget.exercises.isNotEmpty ? widget.exercises.first : '';
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

  void _logWorkoutSession() {
    String logName = selectedExercise;
    if (isSuperSetMode && pairedSuperSetExercise != null) {
      logName = "$selectedExercise + $pairedSuperSetExercise (Super Set)";
    } else if (isDropSetMode) {
      logName = "$selectedExercise (Drop Set)";
    }

    dailyTracker.logExerciseWithSets(
      muscle: widget.muscleName,
      exerciseName: logName,
      sets: currentSets,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Logged $logName to Today\'s Workouts!'),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: Image.asset(
                widget.assetPaths.isNotEmpty ? widget.assetPaths[0] : '',
                errorBuilder: (_, __, ___) => Image.asset(
                  widget.assetPaths.length > 1 ? widget.assetPaths[1] : '',
                  errorBuilder: (_, __, ___) => const Icon(Icons.fitness_center, color: Colors.deepOrange, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text("${widget.muscleName} Workouts"),
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
                    Text("Select Primary Exercise", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: primaryTextColor)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedExercise,
                      decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                      items: widget.exercises.map((ex) => DropdownMenuItem(value: ex, child: Text(ex))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedExercise = val);
                      },
                    ),

                    if (widget.allowAdvancedSets) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Super Set Mode", style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
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
                          hint: const Text("Select Paired Exercise"),
                          decoration: const InputDecoration(labelText: 'Paired Super Set Exercise', border: OutlineInputBorder(), isDense: true),
                          items: widget.exercises.where((e) => e != selectedExercise).map((ex) => DropdownMenuItem(value: ex, child: Text(ex))).toList(),
                          onChanged: (val) => setState(() => pairedSuperSetExercise = val),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Drop Set Mode", style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
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

            Text("Sets Breakdown", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryTextColor)),
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
                        const SizedBox(width: 6),
                        CustomLoadingSwitch(
                          value: setItem.isSpecialSet,
                          onChanged: (val) => setState(() => setItem.isSpecialSet = val),
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
            const SizedBox(height: 12),

            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.deepOrange), minimumSize: const Size.fromHeight(42)),
              onPressed: _addSet,
              icon: const Icon(Icons.add, color: Colors.deepOrange),
              label: const Text("Add Another Set", style: TextStyle(color: Colors.deepOrange)),
            ),
            const SizedBox(height: 20),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, minimumSize: const Size.fromHeight(48)),
              onPressed: _logWorkoutSession,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Log Exercise Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    'Chest': ['Incline Dumbbell Press', 'Pec Dec Flyes', 'Cable Chest Flyes', 'Bench Press'],
    'Back': ['Seated Rows Cable Machine', 'Lat Pulldowns', 'Deadlift'],
    'Legs': ['Bulgarian Split Squat', 'Hack Squat', 'Barbell Squat'],
    'Shoulders': ['Cable Lateral Raises', 'Cable Front Raises', 'Face Pulls'],
    'Biceps': ['Cable Bicep Curls', 'Rope Curls', 'Wide Grip Cable Rod Curls'],
    'Triceps': ['Triceps Rod Pushdown', 'Single Arm Triceps Pushdown', 'Skull Crushers'],
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
        SnackBar(content: Text('Updated PR for $_selectedExercise to $weight kg!')),
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
              Text("Input / Update Personal Record (PR)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
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

              Text("Highest PR Records Stored", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
              const SizedBox(height: 10),

              prs.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Center(child: Text("No PR records stored yet.", style: TextStyle(color: theme.brightness == Brightness.dark ? Colors.grey : Colors.grey[700]))),
                      ),
                    )
                  : Column(
                      children: prs.entries.map((muscleEntry) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ExpansionTile(
                            leading: const Icon(Icons.emoji_events, color: Colors.amber),
                            title: Text("${muscleEntry.key} PRs", style: TextStyle(fontWeight: FontWeight.bold, color: primaryTextColor)),
                            children: muscleEntry.value.entries.map((exEntry) {
                              return ListTile(
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        exEntry.key,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        style: TextStyle(color: primaryTextColor),
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
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Select Target Muscle Group", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
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
                            Expanded(child: Text(ex, style: TextStyle(color: primaryTextColor))),
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
                            Expanded(child: Text(ex, style: TextStyle(color: primaryTextColor))),
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
    final theme = Theme.of(context);
    final primaryTextColor = theme.colorScheme.onSurface;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("AI-Powered Cardio Endurance Tracker", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryTextColor)),
          const SizedBox(height: 10),

          Card(
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