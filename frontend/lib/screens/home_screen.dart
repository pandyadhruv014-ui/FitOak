import 'package:flutter/material.dart';
import '../state/daily_tracker_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
void initState() {
  super.initState();
  dailyTracker.addListener(_updateUi);
  dailyTracker.fetchBackendMeals(); // Pulls saved meals from SQLite on load
}

  @override
  void dispose() {
    dailyTracker.removeListener(_updateUi);
    super.dispose();
  }

  void _updateUi() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final netCalories = (dailyTracker.totalCalories - dailyTracker.totalCaloriesBurned).clamp(0, 10000);

    return Scaffold(
      appBar: AppBar(title: const Text('FitOak Dashboard')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SECTION 1: TODAY'S PROGRESS
              const Text("1. Today's Progress", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Card(
                color: const Color(0xFF1E1E1E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.deepOrange.withAlpha(120))),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.directions_walk, color: Colors.deepOrange, size: 22),
                              SizedBox(width: 8),
                              Text("Daily Activity & Motion", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ],
                          ),
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
                          Expanded(child: _activityMetric("Steps", "${dailyTracker.dailySteps}", "Pedometer")),
                          Expanded(child: _activityMetric("Distance", "${dailyTracker.distanceKm.toStringAsFixed(2)} km", "Motion")),
                          Expanded(child: _activityMetric("Burned", "${dailyTracker.totalCaloriesBurned} kcal", "Motion + Workouts")),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(child: _buildStatCard('Net Calories', '$netCalories kcal', Colors.deepOrange, Icons.local_fire_department)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard('Protein', '${dailyTracker.totalProtein} / 150 g', Colors.blue, Icons.fitness_center)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Carbs', '${dailyTracker.totalCarbs} / 250 g', Colors.green, Icons.grain)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildStatCard('Fats', '${dailyTracker.totalFat} / 70 g', Colors.amber, Icons.opacity)),
                ],
              ),
              const SizedBox(height: 25),

              // SECTION 2: WEEKLY PROGRESS OVERVIEW (GRAPHICAL FORMAT)
              const Text("2. Weekly Progress Overview", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              Card(
                color: const Color(0xFF1E1E1E),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Calories Consumed vs. Burned (Mon - Sun)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 15),

                      // Custom Graphical Bar Chart
                      SizedBox(
                        height: 150,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: dailyTracker.weeklyProgressData.map((data) {
                            double consumedHeight = (data['consumed'] / 3000.0) * 120.0;
                            double burnedHeight = (data['burned'] / 1000.0) * 120.0;

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: consumedHeight.clamp(10, 120),
                                      decoration: BoxDecoration(color: Colors.deepOrange, borderRadius: BorderRadius.circular(4)),
                                    ),
                                    const SizedBox(width: 3),
                                    Container(
                                      width: 8,
                                      height: burnedHeight.clamp(10, 120),
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
                      const SizedBox(height: 15),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.square, color: Colors.deepOrange, size: 12),
                          SizedBox(width: 4),
                          Text("Consumed", style: TextStyle(fontSize: 11, color: Colors.grey)),
                          SizedBox(width: 15),
                          Icon(Icons.square, color: Colors.green, size: 12),
                          SizedBox(width: 4),
                          Text("Burned", style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              const Text("Today's Completed Exercises", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),

              dailyTracker.workoutLog.isEmpty
                  ? const Card(
                      color: Color(0xFF1E1E1E),
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: Text("No exercises logged yet today.", style: TextStyle(color: Colors.grey))),
                      ),
                    )
                  : Column(
                      children: dailyTracker.workoutLog.map((item) {
                        List<SetLog> sets = item['sets'] as List<SetLog>;
                        return Card(
                          color: const Color(0xFF1E1E1E),
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          child: ListTile(
                            leading: const Icon(Icons.fitness_center, color: Colors.deepOrange),
                            title: Text("${item['muscle']} - ${item['exercise']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("${sets.length} sets logged | Max Weight: ${item['maxWeight']} kg"),
                            trailing: Text("-${item['caloriesBurned']} kcal", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityMetric(String label, String value, String subtext) {
    return Column(
      children: [
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.deepOrange))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Text(subtext, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12))),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}