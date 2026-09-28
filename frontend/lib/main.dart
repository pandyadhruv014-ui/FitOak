import 'package:flutter/material.dart';
import 'screens/auth_screens.dart';
import 'state/daily_tracker_state.dart';

// OLD (Local Wi-Fi only):
// const String baseUrl = "http://10.168.226.120:8000";

// NEW (Global Cloud Backend):
const String baseUrl = "https://backend-um5a.onrender.com";

void main() {
  runApp(const FitOakApp());
}

class FitOakApp extends StatelessWidget {
  const FitOakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dailyTracker,
      builder: (context, _) {
        return MaterialApp(
          title: 'FitOak',
          debugShowCheckedModeBanner: false,
          themeMode: dailyTracker.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData.light().copyWith(
            primaryColor: Colors.deepOrange,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
            ),
          ),
          darkTheme: ThemeData.dark().copyWith(
            primaryColor: Colors.deepOrange,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E1E1E),
            ),
          ),
          // Starts with the 9:16 splash screen, then moves to AuthGateScreen
          home: const SplashScreen(nextScreen: AuthGateScreen()),
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  // Handles background data pre-fetching while keeping the splash visible
  Future<void> _initializeApp() async {
    await Future.wait([
      // 1. Minimum display time for branding and smooth transition (2.5 seconds)
      Future.delayed(const Duration(milliseconds: 2500)),
      
      // 2. Preload your initial tokens, user profiles, or backend health checks here
      _fetchInitialData(),
    ]);

    // Once finished, seamlessly switch to the main app flow
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      // Optional: Add your initial backend startup checks here
      // e.g., await http.get(Uri.parse('$baseUrl/'));
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
          fit: BoxFit.cover, // Automatically handles your 2286x4096 9:16 ratio edge-to-edge
        ),
      ),
    );
  }
}