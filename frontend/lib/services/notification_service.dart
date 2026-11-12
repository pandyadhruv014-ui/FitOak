import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    // 1. Initialize timezone database & bind device's real local timezone (e.g., Asia/Kolkata)
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('🕒 Local timezone configured: $timeZoneName');
    } catch (e) {
      // Fallback to IST if device timezone lookup fails
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      debugPrint('⚠️ Fallback timezone set to Asia/Kolkata: $e');
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    // 2. Request Android 13+ notification & Android 12+ exact alarm permissions
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }

    _isInitialized = true;
  }

  /// Immediate test notification to verify permissions & banner display
  Future<void> sendInstantTestNotification() async {
    await init();
    await _notificationsPlugin.show(
      999,
      'FitOak Notifications Active ✅',
      'Your scheduled gym & hydration reminders will appear right here.',
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
    );
  }

  /// Schedules gym reminders for Monday-Saturday (excludes Sunday)
  Future<void> scheduleGymReminder({
    required int hour,
    required int minute,
  }) async {
    await init();

    // Cancel only existing gym reminder IDs (1..6), preserving hydration reminders
    for (int weekday = 1; weekday <= 6; weekday++) {
      await _notificationsPlugin.cancel(weekday);
    }

    final now = tz.TZDateTime.now(tz.local);

    for (int weekday = 1; weekday <= 6; weekday++) {
      var targetTime = _nextInstanceOfWeekday(weekday, hour, minute);

      if (!targetTime.isAfter(now)) {
        targetTime = targetTime.add(const Duration(days: 7));
      }

      await _notificationsPlugin.zonedSchedule(
        weekday,
        'Time to hit the gym! 🏋️',
        'FitOak Reminder: Push your limits today!',
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

      debugPrint('📅 Scheduled Gym Reminder ID=$weekday for $targetTime (${tz.local.name})');
    }
  }

  /// Schedules hydration reminders for Monday-Saturday (excludes Sunday)
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

  Future<void> cancelReminders() async {
    await _notificationsPlugin.cancelAll();
  }
}