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

class _FitOakAppState extends State<FitOakApp> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Request app permissions on app startup
    await [
      Permission.notification,
      Permission.activityRecognition,
      Permission.location,
    ].request();

    // Check saved local login session
    await dailyTracker.checkSavedSession();

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF121212),
          body: Center(
            child: CircularProgressIndicator(color: Colors.deepOrange),
          ),
        ),
      );
    }

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
          home: dailyTracker.isLoggedIn
              ? const MainAppShell()
              : const AuthGateScreen(),
        );
      },
    );
  }
}