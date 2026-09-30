import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  final String backendUrl = "https://backend-um5a.onrender.com";
  
  List<dynamic> meals = [];
  bool isLoading = true;

  // Daily Nutritional Goals
  final double calorieGoal = 2200.0;
  final double proteinGoal = 140.0; // grams
  final double carbsGoal = 250.0;   // grams
  final double fatGoal = 70.0;       // grams

  // Current Totals
  double totalCalories = 0.0;
  double totalProtein = 0.0;
  double totalCarbs = 0.0;
  double totalFat = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchUserMeals();
  }

  Future<void> _fetchUserMeals() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? prefs.getInt('user_id') ?? 0;

      final res = await http.get(Uri.parse('$backendUrl/api/meals/$userId'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final fetchedMeals = data['meals'] ?? [];

        double cals = 0, p = 0, c = 0, f = 0;
        for (var meal in fetchedMeals) {
          cals += (meal['calories'] ?? 0).toDouble();
          p += (meal['protein'] ?? 0).toDouble();
          c += (meal['carbs'] ?? 0).toDouble();
          f += (meal['fat'] ?? 0).toDouble();
        }

        if (mounted) {
          setState(() {
            meals = fetchedMeals.reversed.toList(); // Newest first
            totalCalories = cals;
            totalProtein = p;
            totalCarbs = c;
            totalFat = f;
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading meals: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showAddMealDialog() {
    final dishController = TextEditingController();
    final quantityController = TextEditingController();
    bool isAnalyzing = false;

    showDialog(
      context: context,
      barrierDismissible: !isAnalyzing,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                  SizedBox(width: 8),
                  Text("Log Meal with AI", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Enter food name and quantity—Gemini AI will automatically calculate nutritional macros.",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: dishController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Food / Dish Name",
                        hintText: "e.g., Paneer Tikka or Oats Bowl",
                        prefixIcon: const Icon(Icons.restaurant, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: quantityController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Quantity / Portion Size",
                        hintText: "e.g., 200g or 2 pieces or 1 bowl",
                        prefixIcon: const Icon(Icons.scale, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isAnalyzing)
                      const Column(
                        children: [
                          Center(child: CircularProgressIndicator(color: Colors.orange)),
                          SizedBox(height: 12),
                          Center(
                            child: Text(
                              "Gemini AI analyzing nutrients...",
                              style: TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAnalyzing ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: isAnalyzing
                      ? null
                      : () async {
                          if (dishController.text.trim().isEmpty || quantityController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              const SnackBar(content: Text("Please fill in dish name and quantity.")),
                            );
                            return;
                          }

                          setDialogState(() => isAnalyzing = true);

                          try {
                            final prefs = await SharedPreferences.getInstance();
                            final userId = prefs.getInt('userId') ?? prefs.getInt('user_id') ?? 0;

                            // 1. Fetch AI Nutrients
                            final aiRes = await http.post(
                              Uri.parse('$backendUrl/api/ai/nutrition'),
                              headers: {'Content-Type': 'application/json'},
                              body: json.encode({
                                'dish_name': dishController.text.trim(),
                                'quantity': quantityController.text.trim(),
                              }),
                            );

                            if (aiRes.statusCode == 200) {
                              final aiData = json.decode(aiRes.body)['data'];

                              // 2. Persist Meal to PostgreSQL
                              await http.post(
                                Uri.parse('$backendUrl/api/meals'),
                                headers: {'Content-Type': 'application/json'},
                                body: json.encode({
                                  'user_id': userId,
                                  'name': aiData['meal_name'] ?? dishController.text.trim(),
                                  'quantity': quantityController.text.trim(),
                                  'calories': (aiData['calories'] ?? 0).toInt(),
                                  'protein': (aiData['protein_g'] ?? 0.0).toDouble(),
                                  'carbs': (aiData['carbs_g'] ?? 0.0).toDouble(),
                                  'fat': (aiData['fat_g'] ?? 0.0).toDouble(),
                                }),
                              );

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!mounted) return;
                              _fetchUserMeals(); // Refresh feed and macro bars

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Logged ${aiData['meal_name']} (${aiData['calories']} kcal)!",
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              throw Exception("AI Analysis Failed");
                            }
                          } catch (e) {
                            setDialogState(() => isAnalyzing = false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Error logging meal: $e")),
                            );
                          }
                        },
                  child: const Text("Analyze & Log", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Diet & Meal Tracker"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: _fetchUserMeals,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMealDialog,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.auto_awesome, color: Colors.black),
        label: const Text("Log Meal", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : RefreshIndicator(
              onRefresh: _fetchUserMeals,
              color: Colors.orange,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // --- Daily Macro Progress Overview ---
                  Card(
                    color: const Color(0xFF1E1E1E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Daily Calories", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              Text(
                                "${totalCalories.toInt()} / ${calorieGoal.toInt()} kcal",
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: (totalCalories / calorieGoal).clamp(0.0, 1.0),
                              backgroundColor: Colors.orange.withValues(alpha: 0.15),
                              color: Colors.orange,
                              minHeight: 10,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildMacroIndicator("Protein", totalProtein, proteinGoal, Colors.redAccent, "g"),
                              _buildMacroIndicator("Carbs", totalCarbs, carbsGoal, Colors.blueAccent, "g"),
                              _buildMacroIndicator("Fat", totalFat, fatGoal, Colors.amber, "g"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- Logged Meals List ---
                  const Text(
                    "Today's Meals",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  meals.isEmpty
                      ? Card(
                          color: const Color(0xFF1E1E1E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: const Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              children: [
                                Icon(Icons.no_meals, color: Colors.grey, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  "No meals logged today.",
                                  style: TextStyle(color: Colors.grey, fontSize: 16),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  "Tap 'Log Meal' below to auto-calculate macros with Gemini AI.",
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: meals.length,
                          itemBuilder: (context, index) {
                            final meal = meals[index];
                            return Card(
                              color: const Color(0xFF1E1E1E),
                              margin: const EdgeInsets.only(bottom: 12.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.restaurant_menu, color: Colors.orange),
                                ),
                                title: Text(
                                  meal['name'] ?? 'Meal',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((meal['quantity'] ?? '').toString().isNotEmpty)
                                      Text(
                                        "Portion: ${meal['quantity']}",
                                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "P: ${meal['protein']}g | C: ${meal['carbs']}g | F: ${meal['fat']}g",
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  "${meal['calories']} kcal",
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildMacroIndicator(String title, double current, double goal, Color color, String unit) {
    final progress = (current / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: progress,
                backgroundColor: color.withValues(alpha: 0.15),
                color: color,
                strokeWidth: 5,
              ),
            ),
            Text(
              "${current.toInt()}$unit",
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text("/ ${goal.toInt()}$unit", style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}