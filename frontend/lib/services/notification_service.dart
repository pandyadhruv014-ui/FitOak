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

  /// Schedules gym reminders for non-rest days
  /// [restDays]: List of DateTime weekday ints (1 = Monday, 7 = Sunday)
  Future<void> scheduleGymReminder({
    required int hour,
    required int minute,
    required List<int> restDays,
  }) async {
    await _notificationsPlugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final scheduledDate = now.add(Duration(days: dayOffset));
      final weekday = scheduledDate.weekday;

      // Skip rest days
      if (restDays.contains(weekday)) continue;

      var targetTime = tz.TZDateTime(
        tz.local,
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        hour,
        minute,
      );

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

  Future<void> cancelReminders() async {
    await _notificationsPlugin.cancelAll();
  }
}