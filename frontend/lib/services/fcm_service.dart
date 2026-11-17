import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Top-level background handler required by Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const String backendUrl = "https://backend-um5a.onrender.com";
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();

  bool isChatScreenOpen = false;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localPlugin.initialize(
      const InitializationSettings(android: androidInit),
    );

    // Create high-importance channel for Android 8+
    const channel = AndroidNotificationChannel(
      'gym_squad_chat_channel',
      'Gym Squad Messages',
      description: 'Push notifications for Gym Squad chat messages',
      importance: Importance.max,
    );

    final androidImpl = _localPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(channel);
    await androidImpl?.requestNotificationsPermission();

    // Request FCM permission
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Listen for foreground messages (when app is currently open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (isChatScreenOpen) return;

      final notification = message.notification;
      if (notification != null) {
        _localPlugin.show(
          message.hashCode,
          notification.title ?? 'Gym Squad',
          notification.body ?? 'New message',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'gym_squad_chat_channel',
              'Gym Squad Messages',
              importance: Importance.max,
              priority: Priority.high,
              playSound: true,
            ),
          ),
        );
      }
    });

    // Re-sync token automatically whenever Firebase refreshes it
    messaging.onTokenRefresh.listen((newToken) async {
      await syncTokenWithBackend(tokenOverride: newToken);
    });

    _initialized = true;
  }

  /// Call this right after user login and when app starts with an active session
  Future<void> syncTokenWithBackend({String? tokenOverride}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('userId') ?? prefs.getInt('user_id') ?? 0;
      if (userId <= 0) return;

      final token =
          tokenOverride ?? await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await http
          .post(
            Uri.parse('$backendUrl/api/users/fcm-token'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'fcm_token': token,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('FCM token sync error: $e');
    }
  }
}
