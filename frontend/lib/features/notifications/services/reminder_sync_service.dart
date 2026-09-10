import 'package:frontend/features/notifications/api/notifications_api.dart';
import 'package:frontend/features/notifications/api/token_store.dart';
import 'package:frontend/features/notifications/models/notification_preferences.dart';
import 'package:frontend/features/notifications/models/reminder.dart';
import 'package:frontend/features/notifications/models/scheduled_notification.dart';
import 'package:frontend/features/notifications/services/notification_id.dart';

import 'notification_scheduler.dart';

/// Keeps the device's local notifications in sync with the backend's reminder
/// configuration and the user's preferences.
///
/// Idempotence:
/// 1. Load ALL reminders (including cancelled). Their derived ids cover every
///    notification that this module may have scheduled before, so every stale
///    notification is cancelled first — this prevents duplicates across app
///    restarts without needing to persist locally what was scheduled.
/// 2. Re-schedule the active, future, preference-enabled subset.
class ReminderSyncService {
  ReminderSyncService({
    required NotificationsApi api,
    required NotificationScheduler scheduler,
    required TokenStore tokens,
  })  : _api = api,
        _scheduler = scheduler,
        _tokens = tokens;

  final NotificationsApi _api;
  final NotificationScheduler _scheduler;
  final TokenStore _tokens;

  /// Fetches the user's reminders and preferences and reconciles local
  /// notifications. No-ops when there is no stored token.
  Future<void> refresh() async {
    if (!_tokens.isAuthenticated) return;

    final preferences = await _api.getPreferences();
    final reminders = await _api.listReminders(status: ReminderStatus.all);
    await syncNow(reminders: reminders, preferences: preferences);
  }

  /// Pure scheduling decision: given the reminder set and preferences, cancels
  /// every known reminder notification then schedules the eligible subset.
  Future<void> syncNow({
    required List<Reminder> reminders,
    required NotificationPreferences preferences,
    DateTime? now,
  }) async {
    final reference = (now ?? DateTime.now().toUtc());

    final staleIds = reminders.map((r) => notificationIdFor(r.id));
    await _scheduler.cancelMany(staleIds);

    if (!preferences.enabled) return;

    for (final reminder in reminders) {
      if (!reminder.isActive) continue;
      if (!reminder.scheduledAt.isAfter(reference)) continue;
      if (!preferences.isEnabledFor(reminder.type)) continue;

      final hideContent = preferences.hidesContentFor(reminder.type);
      await _scheduler.schedule(
        ScheduledNotification(
          id: notificationIdFor(reminder.id),
          title: hideContent ? 'Reminder' : reminder.title,
          body: hideContent
              ? 'You have a scheduled reminder'
              : (reminder.body ?? reminder.title),
          when: reminder.scheduledAt.toLocal(),
          payload: reminder.id,
        ),
      );
    }
  }

  /// Removes all reminder notifications (used on logout). Must be called while
  /// the token is still valid so the reminder list can be fetched; clear the
  /// token afterwards.
  Future<void> clearAll() async {
    if (!_tokens.isAuthenticated) return;
    final reminders = await _api.listReminders(status: ReminderStatus.all);
    await _scheduler.cancelMany(
        reminders.map((r) => notificationIdFor(r.id)));
  }
}