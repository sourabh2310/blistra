import 'package:shared_preferences/shared_preferences.dart';

import 'api/auth_api.dart';
import 'api/blistra_api_client.dart';
import 'api/notifications_api.dart';
import 'api/token_store.dart';
import 'services/flutter_notification_scheduler.dart';
import 'services/notification_scheduler.dart';
import 'services/reminder_sync_service.dart';
import 'state/auth_controller.dart';
import 'state/reminders_controller.dart';
import 'state/settings_controller.dart';

/// LEGACY dependency container for the notifications-only prototype.
///
/// Superseded by [AppDependencies] in `app/`. Kept compiling for reference;
/// new wiring must go through `app/app_dependencies.dart` so auth and the
/// shell are not owned by notifications.
class AppDependencies {
  AppDependencies({
    required String baseUrl,
    required SharedPreferences prefs,
    NotificationScheduler? scheduler,
    BlistraApiClient? httpClient,
  }) {
    final client = httpClient ?? BlistraApiClient(baseUrl: baseUrl);
    final tokens = TokenStore(prefs);
    final authApi = AuthApi(client);
    final notificationsApi = NotificationsApi(client);
    final syncScheduler = scheduler ?? FlutterNotificationScheduler();
    final syncService = ReminderSyncService(
      api: notificationsApi,
      scheduler: syncScheduler,
      tokens: tokens,
    );

    authController = AuthController(
      authApi: authApi,
      tokens: tokens,
      syncService: syncService,
    );
    remindersController = RemindersController(api: notificationsApi);
    settingsController = SettingsController(
      api: notificationsApi,
      syncService: syncService,
    );
  }

  late final AuthController authController;
  late final RemindersController remindersController;
  late final SettingsController settingsController;
}