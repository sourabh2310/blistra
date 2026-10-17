import 'package:frontend/features/notifications/api/notifications_api.dart';
import 'package:frontend/features/notifications/api/token_store.dart';
import 'package:frontend/features/notifications/models/notification_preferences.dart';
import 'package:frontend/features/notifications/models/reminder.dart';
import 'package:frontend/features/notifications/models/reminder_type.dart';
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
    required this._api,
    required this._scheduler,
    required this._tokens,
  });

  final NotificationsApi _api;
  final NotificationScheduler _scheduler;
  final TokenStore _tokens;
  int _generation = 0;
  Future<void> _pending = Future.value();

  /// Fetches the user's reminders and preferences and reconciles local
  /// notifications. No-ops when there is no stored token.
  Future<void> refresh() async {
    if (!_tokens.isAuthenticated) return;
    final generation = _generation;
    final preferences = await _api.getPreferences();
    final reminders = await _api.listReminders(status: ReminderStatus.all);
    if (generation != _generation || !_tokens.isAuthenticated) return;
    await syncNow(reminders: reminders, preferences: preferences);
  }

  /// Pure scheduling decision: given the reminder set and preferences, cancels
  /// every known reminder notification then schedules the eligible subset.
  Future<void> syncNow({
    required List<Reminder> reminders,
    required NotificationPreferences preferences,
    DateTime? now,
  }) {
    final generation = _generation;
    final result = _pending.catchError((Object _) {}).then((_) async {
      if (generation != _generation) return;
      await _sync(reminders: reminders, preferences: preferences, now: now);
    });
    _pending = result;
    return result;
  }

  Future<void> _sync({
    required List<Reminder> reminders,
    required NotificationPreferences preferences,
    DateTime? now,
  }) async {
    final reference = (now ?? DateTime.now().toUtc());

    final staleIds = reminders.map((r) => notificationIdFor(r.id));
    await _scheduler.cancelAll();
    await _scheduler.cancelMany(staleIds);

    if (!preferences.enabled) return;

    final ordered = [...reminders]
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    var scheduled = 0;
    for (final reminder in ordered) {
      if (!reminder.isActive) continue;
      if (!reminder.scheduledAt.isAfter(reference)) continue;
      if (!preferences.isEnabledFor(reminder.type)) continue;
      // Stay below iOS's pending-notification limit; show this rolling-window
      // behavior in settings instead of promising unlimited offline delivery.
      if (scheduled++ >= 60) break;

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

  /// Invalidates outstanding refreshes and clears OS state even offline.
  Future<void> clearAll() async {
    _generation++;
    await _pending.catchError((Object _) {});
    await _scheduler.cancelAll();
  }
}
