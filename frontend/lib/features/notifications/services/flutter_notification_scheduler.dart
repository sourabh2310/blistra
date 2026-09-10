import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:frontend/features/notifications/models/scheduled_notification.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'notification_scheduler.dart';

/// Schedules one-off local notifications via the Android notification API
/// using the plugin.
///
/// Reminder times are absolute instants, so scheduling converts them to their
/// UTC wall-clock representation and schedules against the `tz.UTC` location.
/// The OS then fires at the right moment regardless of the device's system
/// timezone. Delivery uses an inexact alarm that works without the Android 12+
/// exact-alarm permission.
class FlutterNotificationScheduler implements NotificationScheduler {
  FlutterNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _androidDetails = AndroidNotificationDetails(
    'blistra_reminders',
    'Reminders',
    channelDescription: 'Scheduled reminders for Blistra',
    importance: Importance.high,
    priority: Priority.high,
  );

  static const _details =
      NotificationDetails(android: _androidDetails);

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(settings);
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();
    return (await _plugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission()) ??
        true;
  }

  @override
  Future<void> schedule(ScheduledNotification notification) async {
    await initialize();
    final whenUtc = notification.when.toUtc();
    final fireAt = tz.TZDateTime.from(
      whenUtc,
      tz.UTC,
    ).subtract(Duration.zero);

    if (!fireAt.isAfter(tz.TZDateTime.now(tz.UTC))) {
      return;
    }

    await _plugin.zonedSchedule(
      notification.id,
      notification.title,
      notification.body,
      fireAt,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: notification.payload,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  @override
  Future<void> cancelMany(Iterable<int> ids) async {
    await initialize();
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }
}