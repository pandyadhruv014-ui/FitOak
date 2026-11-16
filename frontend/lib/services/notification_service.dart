import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _prefGymHour = 'saved_gym_reminder_hour';
  static const String _prefGymMinute = 'saved_gym_reminder_minute';
  static const String _prefGymEnabled = 'saved_gym_reminder_enabled';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(initSettings);

    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    _isInitialized = true;
  }

  /// Returns the user's saved gym reminder TimeOfDay (or null if never set)
  Future<TimeOfDay?> getSavedGymReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefGymEnabled) ?? false;
    final hour = prefs.getInt(_prefGymHour);
    final minute = prefs.getInt(_prefGymMinute);
    if (!enabled || hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Schedules gym reminders for Mon-Sat and persists the exact hour/minute
  Future<void> scheduleGymReminder({
    required int hour,
    required int minute,
    String? updatedByBuddy,
  }) async {
    await init();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefGymHour, hour);
    await prefs.setInt(_prefGymMinute, minute);
    await prefs.setBool(_prefGymEnabled, true);

    for (int weekday = 1; weekday <= 6; weekday++) {
      await _notificationsPlugin.cancel(weekday);
    }

    final now = tz.TZDateTime.now(tz.local);
    final bodyText = (updatedByBuddy != null && updatedByBuddy.isNotEmpty)
        ? 'FitOak Squad ($updatedByBuddy updated time): Push your limits today!'
        : 'FitOak Reminder: Push your limits today!';

    for (int weekday = 1; weekday <= 6; weekday++) {
      var targetTime = _nextInstanceOfWeekday(weekday, hour, minute);
      if (!targetTime.isAfter(now)) {
        targetTime = targetTime.add(const Duration(days: 7));
      }

      await _notificationsPlugin.zonedSchedule(
        weekday,
        'Time to hit the gym! 🏋️',
        bodyText,
        targetTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'gym_reminders_v2',
            'Gym Time Reminders',
            channelDescription: 'Daily notifications for scheduled gym workouts',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }

    debugPrint('📅 Persistent Gym Reminder locked at $hour:${minute.toString().padLeft(2, '0')}');
  }

  /// Schedules hydration reminders for Mon-Sat
  Future<void> scheduleHydrationReminder({
    required int hour,
    required int minute,
  }) async {
    await init();

    for (int weekday = 1; weekday <= 6; weekday++) {
      await _notificationsPlugin.cancel(100 + weekday);
    }

    final now = tz.TZDateTime.now(tz.local);

    for (int weekday = 1; weekday <= 6; weekday++) {
      var targetTime = _nextInstanceOfWeekday(weekday, hour, minute);
      if (!targetTime.isAfter(now)) {
        targetTime = targetTime.add(const Duration(days: 7));
      }

      await _notificationsPlugin.zonedSchedule(
        100 + weekday,
        'Hydration Reminder 💧',
        'FitOak: Stay hydrated! Drink water to reach your daily goal.',
        targetTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hydration_reminders_v2',
            'Hydration Reminders',
            channelDescription: 'Daily water intake reminders',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  Future<void> cancelGymReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefGymEnabled, false);
    for (int weekday = 1; weekday <= 6; weekday++) {
      await _notificationsPlugin.cancel(weekday);
    }
  }

  Future<void> cancelReminders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefGymEnabled, false);
    await _notificationsPlugin.cancelAll();
  }
}