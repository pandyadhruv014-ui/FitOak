import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'main_app_shell.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  String _gender = 'Male';
  String _fitnessGoal = 'Build Muscle';
  bool _isLoading = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    setState(() => _isLoading = true);

    try {
      await http.post(
        Uri.parse('$baseUrl/register'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': _nameController.text.trim(),
          'age': int.tryParse(_ageController.text) ?? 20,
          'gender': _gender,
          'goal': _fitnessGoal,
        }),
      );

      if (!mounted) return;
      _navigateToShell();
    } catch (_) {
      if (mounted) _navigateToShell();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToShell() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainAppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcomeStep(),
            _buildUserInfoStep(),
            _buildGoalStep(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, size: 80, color: Colors.deepOrange),
          const SizedBox(height: 20),
          const Text('Welcome to FitOak', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Your personal AI-driven fitness and strength coach.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, minimumSize: const Size.fromHeight(50)),
            onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            child: const Text('Get Started', style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildUserInfoStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('About You', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 15),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
            items: ['Male', 'Female', 'Other'].map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _gender = val);
            },
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, minimumSize: const Size.fromHeight(50)),
            onPressed: () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
            child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 16)),
          )
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Choose Your Goal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildGoalOption('Build Muscle'),
          _buildGoalOption('Weight Loss'),
          _buildGoalOption('General Fitness'),
          const SizedBox(height: 30),
          _isLoading
              ? const CircularProgressIndicator(color: Colors.deepOrange)
              : ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: _submitRegistration,
                  child: const Text('Complete Setup', style: TextStyle(color: Colors.white, fontSize: 16)),
                )
        ],
      ),
    );
  }

  Widget _buildGoalOption(String title) {
    return InkWell(
      onTap: () => setState(() => _fitnessGoal = title),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            RadioGroup<String>(
              groupValue: _fitnessGoal,
              onChanged: (val) {
                if (val != null) setState(() => _fitnessGoal = val);
              },
              child: Radio<String>(value: title),
            ),
            Text(title, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}