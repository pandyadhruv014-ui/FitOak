import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'state/daily_tracker_state.dart';
import 'screens/auth_screens.dart';
import 'screens/main_app_shell.dart';

const String baseUrl = "https://backend-um5a.onrender.com";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FitOakApp());
}

class FitOakApp extends StatefulWidget {
  const FitOakApp({super.key});

  @override
  State<FitOakApp> createState() => _FitOakAppState();
}

class _FitOakAppState extends State<FitOakApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestAppPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-triggers session & backend database sync when app resumes from background
    if (state == AppLifecycleState.resumed) {
      dailyTracker.checkSavedSession();
    }
  }

  Future<void> _requestAppPermissions() async {
    // Request app permissions on startup
    await [
      Permission.notification,
      Permission.activityRecognition,
      Permission.location,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: dailyTracker,
      builder: (context, _) {
        return MaterialApp(
          title: 'FitOak',
          debugShowCheckedModeBanner: false,
          themeMode: dailyTracker.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: Colors.deepOrange,
            colorScheme: const ColorScheme.dark(primary: Colors.deepOrange),
          ),
          theme: ThemeData.light().copyWith(
            primaryColor: Colors.deepOrange,
            colorScheme: const ColorScheme.light(primary: Colors.deepOrange),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}

// Dynamic Splash Screen that reloads database and session state on open/reopen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _loadAndNavigate();
  }

  Future<void> _loadAndNavigate() async {
    // Allows sufficient time to reload and sync PostgreSQL data in the background
    await dailyTracker.checkSavedSession();
    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    if (dailyTracker.isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainAppShell()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthGateScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Splash Image asset with dark fallback
          Image.asset(
            'assets/splash_background.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: const Color(0xFF121212)),
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.65),
          ),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fitness_center, size: 80, color: Colors.deepOrange),
              SizedBox(height: 20),
              Text(
                "FitOak",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Syncing your fitness data...",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              SizedBox(height: 40),
              CircularProgressIndicator(color: Colors.deepOrange),
            ],
          ),
        ],
      ),
    );
  }
}