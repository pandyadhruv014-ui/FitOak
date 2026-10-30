import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../state/daily_tracker_state.dart';
import 'main_app_shell.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool isLogin = true;
  bool isLoading = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  String selectedGoal = "Build Muscle";

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    dobController.dispose();
    heightController.dispose();
    weightController.dispose();
    super.dispose();
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          title,
          style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
        ),
        content: Text(message, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  Future<void> _submitAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();
    final dob = dobController.text.trim();
    final height = double.tryParse(heightController.text.trim()) ?? 0.0;
    final weight = double.tryParse(weightController.text.trim()) ?? 0.0;

    if (email.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
      _showWarningDialog("Validation Error", "Please fill in all required fields.");
      return;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      _showWarningDialog("Invalid Email", "Please enter a valid email address.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final endpoint = isLogin ? '$baseUrl/api/login' : '$baseUrl/api/register';

      final bodyData = isLogin
          ? jsonEncode({"email": email, "password": password})
          : jsonEncode({
              "name": name,
              "email": email,
              "password": password,
              "dob": dob,
              "height_cm": height,
              "weight_kg": weight,
              "goal": selectedGoal,
            });

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: const {'Content-Type': 'application/json'},
            body: bodyData,
          )
          .timeout(const Duration(seconds: 40));

      if (!mounted) return;

      dynamic data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = null;
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data != null) {
          final user = data['user'] ?? {};
          final int resolvedId = user['id'] ?? data['userId'] ?? data['id'] ?? 0;
          final String resolvedName = user['name'] ?? name;
          final String resolvedEmail = user['email'] ?? email;
          final String resolvedDob = user['dob'] ?? dob;
          final double resolvedHeight = (user['height_cm'] as num?)?.toDouble() ?? height;
          final double resolvedWeight = (user['weight_kg'] as num?)?.toDouble() ?? weight;

          await dailyTracker.saveUserSession(
            id: resolvedId,
            name: resolvedName,
            userEmail: resolvedEmail,
            dobVal: resolvedDob,
            height: resolvedHeight,
            weight: resolvedWeight,
          );
          debugPrint("✅ User session saved!");
          debugPrint("📝 Stored userId: $resolvedId");
          debugPrint("📝 Stored name: $resolvedName");
          debugPrint("📝 Stored email: $resolvedEmail");
          
          final testPrefs = await SharedPreferences.getInstance();
          final savedUserId = testPrefs.getInt('userId');
          debugPrint("🔍 Verification - userId from prefs: $savedUserId");
        }

        if (!mounted) return;

        if (isLogin) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              content: Text("Welcome back, ${dailyTracker.fullName}!"),
            ),
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainAppShell()),
            (route) => false,
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text("Account created successfully! Please log in."),
            ),
          );
          setState(() {
            isLogin = true;
            passwordController.clear();
          });
        }
      } else {
        String errorMessage = (data != null && data['detail'] != null)
            ? data['detail'].toString()
            : "Server error (${response.statusCode}): ${response.body}";
        _showWarningDialog("Authentication Error", errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      _showWarningDialog("Connection Error", "Could not connect to server: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.fitness_center, size: 72, color: Colors.deepOrange),
                const SizedBox(height: 16),
                Text(
                  isLogin ? "Welcome Back to FitOak" : "Create Your Account",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 28),

                if (!isLogin) ...[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(Icons.person, color: Colors.deepOrange),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: dobController,
                          decoration: const InputDecoration(
                            labelText: "DOB (YYYY-MM-DD)",
                            prefixIcon: Icon(Icons.cake, color: Colors.deepOrange),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: heightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Height (cm)",
                            prefixIcon: Icon(Icons.height, color: Colors.deepOrange),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Weight (kg)",
                            prefixIcon: Icon(Icons.monitor_weight, color: Colors.deepOrange),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGoal,
                    decoration: const InputDecoration(
                      labelText: "Primary Goal",
                      prefixIcon: Icon(Icons.flag, color: Colors.deepOrange),
                      border: OutlineInputBorder(),
                    ),
                    items: ['Build Muscle', 'Weight Loss', 'General Fitness']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => selectedGoal = val);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: Icon(Icons.email, color: Colors.deepOrange),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),

                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock, color: Colors.deepOrange),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: isLoading ? null : _submitAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isLogin ? "LOG IN" : "REGISTER",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isLogin ? "Don't have an account?" : "Already have an account?",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(
                        isLogin ? "Register" : "Log In",
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}