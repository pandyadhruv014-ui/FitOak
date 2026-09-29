import 'package:flutter/material.dart';
import '../state/daily_tracker_state.dart';

class DietTabScreen extends StatefulWidget {
  const DietTabScreen({super.key});

  @override
  State<DietTabScreen> createState() => _DietTabScreenState();
}

class _DietTabScreenState extends State<DietTabScreen> {
  String _selectedDay = 'Monday';
  String _selectedMealCategory = 'Breakfast';

  final TextEditingController _foodNameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    dailyTracker.addListener(_refresh);
  }

  @override
  void dispose() {
    dailyTracker.removeListener(_refresh);
    _foodNameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _showAddMealModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 20.0,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20.0,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Log Meal Entry for $_selectedDay", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                const SizedBox(height: 15),

                DropdownButtonFormField<String>(
                  initialValue: _selectedMealCategory,
                  decoration: const InputDecoration(labelText: 'Meal Category', border: OutlineInputBorder()),
                  items: ['Breakfast', 'Lunch', 'Dinner', 'Snacks']
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMealCategory = val);
                  },
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _foodNameController,
                  decoration: const InputDecoration(labelText: 'Food / Dish Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _caloriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Calories (kcal)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _proteinController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Protein (g)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _carbsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Carbs (g)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _fatController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fat (g)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    final name = _foodNameController.text.trim();
                    final cals = int.tryParse(_caloriesController.text.trim()) ?? 0;
                    final protein = int.tryParse(_proteinController.text.trim()) ?? 0;
                    final carbs = int.tryParse(_carbsController.text.trim()) ?? 0;
                    final fat = int.tryParse(_fatController.text.trim()) ?? 0;

                    if (name.isNotEmpty && cals > 0) {
                      dailyTracker.logUserMeal(
                        day: _selectedDay,
                        mealCategory: _selectedMealCategory,
                        foodName: name,
                        calories: cals,
                        protein: protein,
                        carbs: carbs,
                        fat: fat,
                      );

                      _foodNameController.clear();
                      _caloriesController.clear();
                      _proteinController.clear();
                      _carbsController.clear();
                      _fatController.clear();

                      Navigator.pop(ctx);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Logged "$name" to $_selectedDay diet!')),
                      );
                    }
                  },
                  icon: const Icon(Icons.check, color: Colors.white),
                  label: const Text('Save Entry to Weekly Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dayMeals = dailyTracker.weeklyUserDietLog[_selectedDay] ?? [];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Weekly Diet Logger", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange),
                onPressed: _showAddMealModal,
                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                label: const Text("Log Meal", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 15),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
                final isSelected = _selectedDay == day;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(day),
                    selected: isSelected,
                    selectedColor: Colors.deepOrange,
                    onSelected: (val) {
                      if (val) setState(() => _selectedDay = day);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 20),

          Text("User Logged Entries for $_selectedDay", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amber)),
          const SizedBox(height: 10),

          dayMeals.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      "No meals logged for $_selectedDay yet.\nTap 'Log Meal' above to enter what you ate.",
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : Column(
                  children: dayMeals.map((meal) {
                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: ListTile(
                        leading: const Icon(Icons.fastfood, color: Colors.deepOrange),
                        title: Text("${meal['category']}: ${meal['name']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${meal['calories']} kcal | P: ${meal['protein']}g | C: ${meal['carbs']}g | F: ${meal['fat']}g"),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}