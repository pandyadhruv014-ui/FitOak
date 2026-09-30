import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main_app_shell.dart';

class OnboardingScreen extends StatefulWidget {
  final String name;
  final String email;
  final String password;

  const OnboardingScreen({
    super.key,
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final String backendUrl = "https://backend-um5a.onrender.com";

  final _dobController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();

  String selectedGender = 'Male';
  String selectedGoal = 'Build Muscle';
  bool isLoading = false;

  final List<String> genderOptions = ['Male', 'Female', 'Other'];
  final List<String> goalOptions = ['Build Muscle', 'Fat Loss', 'Maintain Fitness', 'Increase Endurance'];

  Future<void> _completeRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': widget.name,
          'email': widget.email,
          'password': widget.password,
          'dob': _dobController.text,
          'height_cm': double.tryParse(_heightController.text) ?? 0.0,
          'weight_kg': double.tryParse(_weightController.text) ?? 0.0,
          'gender': selectedGender,
          'goal': selectedGoal,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        final user = data['user'];
        await prefs.setInt('user_id', user['id']);
        await prefs.setString('user_name', user['name']);
        await prefs.setString('user_email', user['email']);

        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainAppShell()),
            (route) => false,
          );
        }
      } else {
        throw Exception(data['detail'] ?? "Registration failed");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complete Your Profile"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Personal Details",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "This helps FitOak calculate accurate calorie targets and personalized fitness metrics.",
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _dobController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Date of Birth (DD/MM/YYYY)",
                  prefixIcon: const Icon(Icons.calendar_today, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val == null || val.isEmpty ? "Please enter DOB" : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Height (cm)",
                        prefixIcon: const Icon(Icons.height, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Weight (kg)",
                        prefixIcon: const Icon(Icons.monitor_weight, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) => val == null || val.isEmpty ? "Required" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: selectedGender,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: InputDecoration(
                  labelText: "Gender",
                  prefixIcon: const Icon(Icons.person, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (val) => setState(() => selectedGender = val!),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: selectedGoal,
                dropdownColor: const Color(0xFF1E1E1E),
                decoration: InputDecoration(
                  labelText: "Primary Fitness Goal",
                  prefixIcon: const Icon(Icons.track_changes, color: Colors.orange),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: goalOptions.map((goal) => DropdownMenuItem(value: goal, child: Text(goal))).toList(),
                onChanged: (val) => setState(() => selectedGoal = val!),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: isLoading ? null : _completeRegistration,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text(
                          "Get Started",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}