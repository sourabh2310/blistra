import 'package:frontend/features/notifications/models/scheduled_notification.dart';

/// Abstraction over the device's local-notification scheduling.
///
/// The real implementation uses `flutter_local_notifications`; tests inject a
/// fake so scheduling decisions can be verified without OS plugins.
abstract interface class NotificationScheduler {
  Future<void> initialize();

  Future<bool> requestPermissions();

  /// Schedules a single one-off local notification.
  Future<void> schedule(ScheduledNotification notification);

  /// Removes a previously scheduled notification by id (no-op if absent).
  Future<void> cancel(int id);

  /// Removes several previously scheduled notifications.
  Future<void> cancelMany(Iterable<int> ids);
}