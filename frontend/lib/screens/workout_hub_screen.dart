import 'package:flutter/material.dart';
import '../state/daily_tracker_state.dart';
import 'diet_screen.dart';
import 'trackers_screen.dart';

class WorkoutHubScreen extends StatelessWidget {
  const WorkoutHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout & Health Hub'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            "Select Hub Category",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          _buildHubCard(
            context,
            title: 'Strength Training',
            subtitle: 'Select muscle groups, specific exercises, sets, reps & weight',
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
            subtitle: 'View your personal best weights across all muscle groups',
            icon: Icons.emoji_events,
            color: Colors.amber,
            destination: const ScaffoldPageWrapper(
              title: 'Highest PR Records',
              child: PersonalRecordsScreen(),
            ),
          ),
          _buildHubCard(
            context,
            title: 'Diet & Meal Plan',
            subtitle: 'View weekly diet recommendations and logged meals',
            icon: Icons.restaurant,
            color: Colors.green,
            destination: const ScaffoldPageWrapper(
              title: 'Diet & Meal Plan',
              child: DietTabScreen(),
            ),
          ),
          _buildHubCard(
            context,
            title: 'Trackers (Nutrition & Activity)',
            subtitle: 'Fetch nutrition values and sync mobile health app data',
            icon: Icons.track_changes,
            color: Colors.blue,
            destination: const ScaffoldPageWrapper(
              title: 'Health & Nutrition Trackers',
              child: TrackersTabScreen(),
            ),
          ),
          _buildHubCard(
            context,
            title: 'Warmup Routines',
            subtitle: 'Dynamic stretches and injury prevention guides',
            icon: Icons.self_improvement,
            color: Colors.purple,
            destination: const SimpleContentScreen(title: 'Warmup Routines'),
          ),
          _buildHubCard(
            context,
            title: 'Cardio Sessions',
            subtitle: 'Running, walking, cycling endurance tracking',
            icon: Icons.directions_run,
            color: Colors.teal,
            destination: const SimpleContentScreen(title: 'Cardio Sessions'),
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

// Wrapper to display modular screens inside clean sub-pages with an AppBar
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

class SimpleContentScreen extends StatelessWidget {
  final String title;
  const SimpleContentScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Content for $title coming soon!',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}

// ==========================================
// STRENGTH SECTION (PER-SET CUSTOMIZABLE LOGGING)
// ==========================================
class StrengthMuscleSelectorScreen extends StatefulWidget {
  const StrengthMuscleSelectorScreen({super.key});

  @override
  State<StrengthMuscleSelectorScreen> createState() => _StrengthMuscleSelectorScreenState();
}

class _StrengthMuscleSelectorScreenState extends State<StrengthMuscleSelectorScreen> {
  final Map<String, List<String>> muscleExerciseMap = {
    'Chest': ['Incline Bench Press', 'Flat Dumbbell Press', 'Chest Flyes', 'Dips'],
    'Back': ['Lat Pulldowns', 'Barbell Rows', 'Deadlifts', 'Face Pulls'],
    'Shoulders': ['Overhead Shoulder Press', 'Lateral Raises', 'Front Raises'],
    'Biceps': ['Barbell Curls', 'Hammer Curls', 'Preacher Curls'],
    'Triceps': ['Triceps Rope Pushdowns', 'Skull Crushers', 'Overhead Extensions'],
    'Legs': ['Barbell Squats', 'Leg Press', 'Romanian Deadlifts', 'Calf Raises'],
    'Abs': ['Cable Crunches', 'Hanging Leg Raises', 'Plank Holds'],
  };

  String? selectedMuscle;
  String? selectedExercise;

  List<SetLog> currentSets = [
    SetLog(setNumber: 1, reps: 12, weight: 20.0),
    SetLog(setNumber: 2, reps: 10, weight: 25.0),
    SetLog(setNumber: 3, reps: 8, weight: 30.0),
  ];

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
      selectedExercise = null;
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
          const Text("Select Target Muscle Group", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: muscleExerciseMap.keys.map((muscle) {
              final isSelected = selectedMuscle == muscle;
              return ChoiceChip(
                label: Text(muscle),
                selected: isSelected,
                selectedColor: Colors.deepOrange,
                onSelected: (selected) {
                  setState(() {
                    selectedMuscle = selected ? muscle : null;
                    selectedExercise = null;
                  });
                },
              );
            }).toList(),
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
                            tooltip: 'Toggle Drop/Super Set',
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

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.deepOrange)),
                      onPressed: _addSet,
                      icon: const Icon(Icons.add, color: Colors.deepOrange),
                      label: const Text("Add Another Set", style: TextStyle(color: Colors.deepOrange)),
                    ),
                  ),
                ],
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
// HIGHEST PR RECORDS MENU
// ==========================================
class PersonalRecordsScreen extends StatelessWidget {
  const PersonalRecordsScreen({super.key});

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
              const Text("Highest PR Records per Muscle Group", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              prs.isEmpty
                  ? const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(child: Text("No PR records stored yet. Log heavier weights in Strength workouts!")),
                      ),
                    )
                  : Column(
                      children: prs.entries.map((muscleEntry) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ExpansionTile(
                            leading: const Icon(Icons.emoji_events, color: Colors.amber),
                            title: Text("${muscleEntry.key} PRs", style: const TextStyle(fontWeight: FontWeight.bold)),
                            children: muscleEntry.value.entries.map((exEntry) {
                              return ListTile(
                                title: Text(exEntry.key),
                                trailing: Text("${exEntry.value} kg", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
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