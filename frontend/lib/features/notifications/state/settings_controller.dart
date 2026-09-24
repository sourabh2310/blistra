import 'package:flutter/foundation.dart';
import 'package:frontend/features/notifications/api/notifications_api.dart';
import 'package:frontend/features/notifications/models/notification_preferences.dart';
import 'package:frontend/features/notifications/services/reminder_sync_service.dart';

import '../../../core/api/api_exception.dart';

/// Backs the notification settings screen and keeps preferences in sync with
/// the backend. After each change the local schedule is recalculated so toggles
/// take effect immediately.
class SettingsController extends ChangeNotifier {
  SettingsController({
    required this._api,
    required this._syncService,
  });

  final NotificationsApi _api;
  final ReminderSyncService _syncService;

  NotificationPreferences _preferences = NotificationPreferences.defaults();
  bool _loading = false;
  String? _error;
  bool _saving = false;

  NotificationPreferences get preferences => _preferences;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _preferences = await _api.getPreferences();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> update({
    bool? enabled,
    bool? medicineEnabled,
    bool? habitEnabled,
    bool? plannerEnabled,
    bool? healthEnabled,
    bool? generalEnabled,
    bool? hideSensitiveContent,
  }) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _preferences = await _api.updatePreferences(
        enabled: enabled,
        medicineEnabled: medicineEnabled,
        habitEnabled: habitEnabled,
        plannerEnabled: plannerEnabled,
        healthEnabled: healthEnabled,
        generalEnabled: generalEnabled,
        hideSensitiveContent: hideSensitiveContent,
      );
      await _syncService.refresh();
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}