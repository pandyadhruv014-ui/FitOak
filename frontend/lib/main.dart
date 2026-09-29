import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'screens/auth_screens.dart';
import 'state/daily_tracker_state.dart';

// Global Cloud Backend URL:
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

  Future<void> _initializeApp() async {
    await Future.wait([
      Future.delayed(const Duration(milliseconds: 2500)),
      _fetchInitialData(),
    ]);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget.nextScreen),
      );
    }
  }

  Future<void> _fetchInitialData() async {
    try {
      // Ping Render backend to wake up free tier instance
      await http.get(Uri.parse('$baseUrl/')).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint("Backend ping error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Image.asset(
          'assets/splash_background.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}