import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);

    // Request permissions at runtime for Android 13+ and Exact Alarms
    final androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
  }

  /// Schedules gym reminders for Monday-Saturday (excludes Sunday)
  Future<void> scheduleGymReminder({
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    for (int weekday = 1; weekday <= 6; weekday++) {
      var targetTime = _nextInstanceOfWeekday(weekday, hour, minute);

      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 7));
      }

      await _notificationsPlugin.zonedSchedule(
        weekday,
        'Time to hit the gym! 🏋️',
        'FitOak Reminder: Push your limits today!',
        targetTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'gym_reminders_channel',
            'Gym Time Reminders',
            channelDescription: 'Daily notifications for scheduled gym workouts',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Schedules hydration reminders for Monday-Saturday (excludes Sunday)
  Future<void> scheduleHydrationReminder({
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);

    for (int weekday = 1; weekday <= 6; weekday++) {
      var targetTime = _nextInstanceOfWeekday(weekday, hour, minute);

      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 7));
      }

      await _notificationsPlugin.zonedSchedule(
        100 + weekday,
        'Hydration Reminder 💧',
        'FitOak: Stay hydrated! Drink water to reach your daily goal.',
        targetTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hydration_reminders_channel',
            'Hydration Reminders',
            channelDescription: 'Daily water intake reminders',
            importance: Importance.max,
            priority: Priority.high,
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