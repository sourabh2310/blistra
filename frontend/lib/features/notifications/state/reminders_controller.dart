import 'package:flutter/foundation.dart';
import 'package:frontend/features/notifications/api/notifications_api.dart';
import 'package:frontend/features/notifications/models/reminder.dart';
import 'package:frontend/features/notifications/models/reminder_type.dart';

import '../../../core/api/api_exception.dart';

/// Backs the reminders list screen: loading, create/update/cancel (soft
/// delete) and an in-memory refresh of the current user's SCHEDULED reminders.
class RemindersController extends ChangeNotifier {
  RemindersController({required this._api});

  final NotificationsApi _api;

  List<Reminder> _reminders = const [];
  bool _loading = false;
  String? _error;
  String? _message;

  List<Reminder> get reminders => _reminders;
  bool get loading => _loading;
  String? get error => _error;
  String? get message => _message;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _reminders = await _api.listReminders();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> create({
    required String title,
    String? body,
    required DateTime scheduledAtUtc,
    required String timezone,
  }) async {
    await _mutate(() => _api.createReminder(
          title: title,
          body: body,
          scheduledAtUtc: scheduledAtUtc,
          timezone: timezone,
        ));
  }

  Future<void> update(
    String id, {
    String? title,
    String? body,
    DateTime? scheduledAtUtc,
    String? timezone,
  }) async {
    await _mutate(() => _api.updateReminder(
          id,
          title: title,
          body: body,
          scheduledAtUtc: scheduledAtUtc,
          timezone: timezone,
        ));
  }

  Future<void> cancel(String id) async {
    await _mutate(() async {
      await _api.cancelReminder(id);
      return null;
    });
  }

  Reminder? reminderById(String id) {
    for (final reminder in _reminders) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }

  String labelFor(ReminderType type) => switch (type) {
        ReminderType.medicine => 'Medicine',
        ReminderType.habit => 'Habit',
        ReminderType.planner => 'Planner',
        ReminderType.health => 'Health',
        ReminderType.general => 'General',
      };

  Future<void> _mutate(Future<Reminder?> Function() action) async {
    _message = null;
    _error = null;
    notifyListeners();
    try {
      await action();
      await load();
      _message = 'Saved';
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      notifyListeners();
    }
  }
}