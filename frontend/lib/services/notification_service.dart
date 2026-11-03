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
  }

  /// Schedules gym reminders for Monday-Saturday (excludes Sunday)
  /// [hour] and [minute]: Time to send the notification
  Future<void> scheduleGymReminder({
    required int hour,
    required int minute,
  }) async {
    await _notificationsPlugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    // Schedule for Monday (1) through Saturday (6), excluding Sunday (7)
    for (int weekday = 1; weekday <= 6; weekday++) {
      var targetTime = _nextInstanceOfWeekday(weekday, hour, minute);

      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 7));
      }

      await _notificationsPlugin.zonedSchedule(
        weekday, // Use weekday as notification ID
        'Time to hit the gym! 🏋️',
        'FitOak Reminder: Push your limits today!',
        targetTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'gym_reminders_channel',
            'Gym Time Reminders',
            channelDescription: 'Daily notifications for scheduled gym workouts',
            importance: Importance.high,
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

    // Schedule for Monday (1) through Saturday (6), excluding Sunday (7)
    for (int weekday = 1; weekday <= 6; weekday++) {
      var targetTime = _nextInstanceOfWeekday(weekday, hour, minute);

      if (targetTime.isBefore(now)) {
        targetTime = targetTime.add(const Duration(days: 7));
      }

      await _notificationsPlugin.zonedSchedule(
        100 + weekday, // Offset ID to avoid conflict with gym reminders
        'Hydration Reminder 💧',
        'FitOak: Stay hydrated! Drink water to reach your daily goal.',
        targetTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'hydration_reminders_channel',
            'Hydration Reminders',
            channelDescription: 'Daily water intake reminders',
            importance: Importance.high,
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