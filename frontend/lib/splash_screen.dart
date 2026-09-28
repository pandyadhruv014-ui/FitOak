import 'package:flutter/material.dart';
// Import your home screen here when ready
// import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // Handle data loading and minimum display timer concurrently
  Future<void> _initializeApp() async {
    await Future.wait([
      // 1. Keep splash visible for at least 2.5 seconds for branding and smoothness
      Future.delayed(const Duration(milliseconds: 2500)),
      
      // 2. Fetch your initial backend data, user profile, or tokens here
      _fetchBackendData(),
    ]);

    // Once data is ready, navigate to the main screen and remove splash from stack
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const PlaceholderHomeScreen()),
      );
    }
  }

  Future<void> _fetchBackendData() async {
    try {
      // Example: Call your FastAPI backend initial health check or user prefetch
      // final response = await http.get(Uri.parse('http://YOUR_PC_IP:8000/'));
    } catch (e) {
      debugPrint("Startup data fetch error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash_background.png',
          fit: BoxFit.cover, // Forces the 9:16 image to cover the entire screen proportionally
        ),
      ),
    );
  }
}

// Temporary placeholder for your actual Home Screen
class PlaceholderHomeScreen extends StatelessWidget {
  const PlaceholderHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FitOak Home")),
      body: const Center(child: Text("Welcome to FitOak!")),
    );
  }
}