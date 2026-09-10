import 'package:frontend/notifications/models/notification_preferences.dart';
import 'package:frontend/notifications/models/reminder.dart';
import 'package:frontend/notifications/models/reminder_type.dart';

import 'blistra_api_client.dart';

/// Client for the Notifications platform API under `/api/v1/notifications`.
class NotificationsApi {
  NotificationsApi(this._client);

  final BlistraApiClient _client;

  static const String _remindersPath = '/api/v1/notifications/reminders';
  static const String _preferencesPath = '/api/v1/notifications/preferences';
  static const String _devicesPath = '/api/v1/notifications/devices';

  Future<List<Reminder>> listReminders({ReminderStatus? status}) async {
    final query =
        (status != null && status != ReminderStatus.scheduled)
            ? '?status=${status.wire}'
            : '';
    final list = await _client.getList('$_remindersPath$query');
    return list
        .map((item) => Reminder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Reminder> createReminder({
    required String title,
    String? body,
    required DateTime scheduledAtUtc,
    required String timezone,
  }) async {
    final json = await _client.post(_remindersPath, body: {
      'type': ReminderType.general.wire,
      'title': title,
      if (body != null && body.isNotEmpty) 'body': body,
      'scheduledAt': scheduledAtUtc.toUtc().toIso8601String(),
      'timezone': timezone,
    });
    return Reminder.fromJson(json);
  }

  Future<Reminder> updateReminder(
    String id, {
    String? title,
    String? body,
    DateTime? scheduledAtUtc,
    String? timezone,
  }) async {
    final json = await _client.put('$_remindersPath/$id', body: {
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (scheduledAtUtc != null)
        'scheduledAt': scheduledAtUtc.toUtc().toIso8601String(),
      if (timezone != null) 'timezone': timezone,
    });
    return Reminder.fromJson(json);
  }

  Future<void> cancelReminder(String id) =>
      _client.delete('$_remindersPath/$id');

  Future<NotificationPreferences> getPreferences() async {
    final json = await _client.get(_preferencesPath);
    return NotificationPreferences.fromJson(json);
  }

  Future<NotificationPreferences> updatePreferences({
    bool? enabled,
    bool? medicineEnabled,
    bool? habitEnabled,
    bool? plannerEnabled,
    bool? healthEnabled,
    bool? generalEnabled,
    bool? hideSensitiveContent,
  }) async {
    final json = await _client.put(_preferencesPath, body: {
      if (enabled != null) 'enabled': enabled,
      if (medicineEnabled != null) 'medicineEnabled': medicineEnabled,
      if (habitEnabled != null) 'habitEnabled': habitEnabled,
      if (plannerEnabled != null) 'plannerEnabled': plannerEnabled,
      if (healthEnabled != null) 'healthEnabled': healthEnabled,
      if (generalEnabled != null) 'generalEnabled': generalEnabled,
      if (hideSensitiveContent != null)
        'hideSensitiveContent': hideSensitiveContent,
    });
    return NotificationPreferences.fromJson(json);
  }

  Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required String pushToken,
    required DevicePlatform platform,
  }) =>
      _client.post(_devicesPath, body: {
        'deviceId': deviceId,
        'pushToken': pushToken,
        'platform': platform.wire,
      });

  Future<List<Map<String, dynamic>>> listDevices() async {
    final list = await _client.getList(_devicesPath);
    return list.cast<Map<String, dynamic>>();
  }

  Future<void> removeDevice(String id) => _client.delete('$_devicesPath/$id');
}