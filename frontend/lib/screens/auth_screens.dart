import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart'; // Imports baseUrl defined in main.dart

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool isLogin = true;
  bool isLoading = false;

  // Text Form Controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // --- Helper to show warning popups ---
  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK", style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  // --- Backend Authentication Handler ---
  Future<void> _submitAuth() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    // Client-side Validation
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
      if (isLogin) {
        // --- LOGIN FLOW ---
        final response = await http.post(
          Uri.parse('$baseUrl/api/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "email": email,
            "password": password,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final userName = data['user']['name'] ?? 'User';

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Welcome back, $userName!")),
            );

            // Navigate to Home Screen and clear navigation stack
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(userName: userName),
              ),
            );
          }
        } else {
          // Backend returned 401/400 (Unregistered user or wrong password)
          final errorData = jsonDecode(response.body);
          String errorMessage = errorData['detail'] ?? "Login failed. Please check your credentials.";
          _showWarningDialog("Authentication Failed", errorMessage);
        }
      } else {
        // --- REGISTER FLOW ---
        final response = await http.post(
          Uri.parse('$baseUrl/api/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "name": name,
            "email": email,
            "password": password,
          }),
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Registration successful! Please log in.")),
            );
            setState(() {
              isLogin = true; // Switch to login view after registration
              passwordController.clear();
            });
          }
        } else {
          final errorData = jsonDecode(response.body);
          String errorMessage = errorData['detail'] ?? "Registration failed. Try again.";
          _showWarningDialog("Registration Error", errorMessage);
        }
      }
    } catch (e) {
      _showWarningDialog(
        "Connection Error",
        "Could not reach the backend server ($baseUrl). Make sure your FastAPI backend is running.",
      );
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
                const SizedBox(height: 32),

                // Name Field (Only visible during Registration)
                if (!isLogin) ...[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email Field
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email Address",
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: isLoading ? null : _submitAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isLogin ? "LOG IN" : "REGISTER",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
                const SizedBox(height: 16),

                // Switch between Login and Register modes
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isLogin ? "Don't have an account?" : "Already have an account?"),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isLogin = !isLogin;
                        });
                      },
                      child: Text(
                        isLogin ? "Register" : "Log In",
                        style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
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

// Destination Screen loaded upon successful login
class HomeScreen extends StatelessWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FitOak Dashboard"),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthGateScreen()),
              );
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              "Welcome, $userName!",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text("You are securely logged into FitOak."),
          ],
        ),
      ),
    );
  }
}