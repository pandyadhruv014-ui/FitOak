import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'state/daily_tracker_state.dart';
import 'services/notification_service.dart';
import 'splash_screen.dart';

const String baseUrl = "https://backend-um5a.onrender.com";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const FitOakApp());
}

class FitOakApp extends StatefulWidget {
  const FitOakApp({super.key});

  @override
  State<FitOakApp> createState() => _FitOakAppState();
}

class _FitOakAppState extends State<FitOakApp> with WidgetsBindingObserver {
  Timer? _keepAliveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestAppPermissions();
    _startKeepAlive(); // Start keep-alive pings
  }

  @override
  void dispose() {
    _keepAliveTimer?.cancel(); // Cancel timer when app closes
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      dailyTracker.checkSavedSession();
      _startKeepAlive(); // Restart keep-alive when app resumes
    } else if (state == AppLifecycleState.paused) {
      _keepAliveTimer?.cancel(); // Stop pinging when app is in background
    }
  }

  Future<void> _requestAppPermissions() async {
    await [
      Permission.notification,
      Permission.activityRecognition,
      Permission.sensors,
      Permission.location,
    ].request();
  }

  // Keep-Alive Function to prevent Render backend from sleeping
  void _startKeepAlive() {
    _keepAliveTimer?.cancel(); // Cancel existing timer if any
    
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 10), (timer) async {
      try {
        final response = await http
            .get(Uri.parse('$baseUrl/health'))
            .timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          debugPrint("🏓 Keep-alive ping successful - Server is awake");
        } else {
          debugPrint("🏓 Keep-alive ping returned status: ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("🏓 Keep-alive ping failed: $e");
      }
    });
    
    debugPrint("✅ Keep-alive timer started (pings every 10 minutes)");
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
          
          // DARK THEME CONFIGURATION
          darkTheme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: const Color(0xFF121212),
            primaryColor: Colors.deepOrange,
            cardColor: const Color(0xFF1E1E1E),
            colorScheme: const ColorScheme.dark(
              primary: Colors.deepOrange,
              surface: Color(0xFF1E1E1E),
              onSurface: Colors.white,
            ),
            cardTheme: CardThemeData(
              color: const Color(0xFF1E1E1E),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.3)),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
          ),

          // LIGHT THEME CONFIGURATION
          theme: ThemeData.light().copyWith(
            scaffoldBackgroundColor: const Color(0xFFF5F5F5),
            primaryColor: Colors.deepOrange,
            cardColor: Colors.white,
            colorScheme: const ColorScheme.light(
              primary: Colors.deepOrange,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.5)),
              ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 1,
            ),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}