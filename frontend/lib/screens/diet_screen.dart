import 'package:flutter/material.dart';
import '../state/daily_tracker_state.dart';

class DietTabScreen extends StatefulWidget {
  const DietTabScreen({super.key});

  @override
  State<DietTabScreen> createState() => _DietTabScreenState();
}

class _DietTabScreenState extends State<DietTabScreen> {
  @override
  void initState() {
    super.initState();
    dailyTracker.addListener(_refresh);
  }

  @override
  void dispose() {
    dailyTracker.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text("Today's Verified Meals", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          dailyTracker.todayLog.isEmpty
              ? const Text("No meals added to today's diet yet. Use the Trackers tab to fetch accurate meal data.", style: TextStyle(color: Colors.grey))
              : Column(
                  children: dailyTracker.todayLog.map((meal) {
                    return Card(
                      color: const Color(0xFF1E1E1E),
                      child: ListTile(
                        leading: const Icon(Icons.restaurant, color: Colors.deepOrange),
                        title: Text(meal['name']),
                        subtitle: Text('${meal['calories']} kcal | P: ${meal['protein']}g | C: ${meal['carbs']}g | F: ${meal['fat']}g'),
                      ),
                    );
                  }).toList(),
                ),
          const Divider(height: 40),
          const Text("Weekly Recommended Diet Plan", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildDayDietCard('Monday', 'Breakfast: Oatmeal & Eggs\nLunch: Chicken Breast & Rice\nDinner: Salmon & Asparagus'),
          _buildDayDietCard('Tuesday', 'Breakfast: Greek Yogurt & Berries\nLunch: Turkey Wrap & Greens\nDinner: Lean Beef Stir Fry'),
          _buildDayDietCard('Wednesday', 'Breakfast: Protein Smoothie\nLunch: Tuna Salad Bowl\nDinner: Grilled Tofu & Quinoa'),
        ],
      ),
    );
  }

  Widget _buildDayDietCard(String day, String plan) {
    return Card(
      color: const Color(0xFF1E1E1E),
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        title: Text(day, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
        subtitle: Text(plan),
      ),
    );
  }
}