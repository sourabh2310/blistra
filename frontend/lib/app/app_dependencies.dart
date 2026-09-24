/// Central dependency graph for the Blistra app.
///
/// Replaces the notifications-owned `AppDependencies`: the session, HTTP
/// client and every feature controller are built here once, from [AppConfig],
/// and exposed to the widget tree by [AppShell] (via [AppScope] + `provider`).
///
/// Local notifications are wired but never initialized here and permissions
/// are never requested at startup — see [AppShell] / settings.
library;

import '../core/api/api_client.dart';
import '../core/auth/auth_state.dart';
import '../core/auth/auth_storage.dart';
import '../core/config/app_config.dart';
import '../features/dashboard/dashboard_api.dart';
import '../features/dashboard/dashboard_controller.dart';
import '../features/diet/diet_api.dart';
import '../features/diet/diet_controller.dart';
import '../features/documents/providers/documents_provider.dart';
import '../features/documents/repositories/documents_repository.dart';
import '../features/finance/finance_api.dart';
import '../features/finance/finance_controller.dart';
import '../features/habits/habits_api.dart';
import '../features/habits/habits_controller.dart';
import '../features/health/health_api.dart';
import '../features/health/health_repository.dart';
import '../features/notifications/api/blistra_api_client.dart';
import '../features/notifications/api/notifications_api.dart';
import '../features/notifications/api/token_store.dart';
import '../features/notifications/services/flutter_notification_scheduler.dart';
import '../features/notifications/services/notification_scheduler.dart';
import '../features/notifications/services/reminder_sync_service.dart';
import '../features/notifications/state/reminders_controller.dart';
import '../features/notifications/state/settings_controller.dart';
import '../features/planner/planner_api.dart';
import '../features/planner/planner_controller.dart';
import '../features/profile/profile_controller.dart';

class AppDependencies {
  AppDependencies._({
    required this.apiClient,
    required this.authState,
    required this.authStorage,
    required this.dashboard,
    required this.planner,
    required this.profile,
    required this.diet,
    required this.habits,
    required this.finance,
    required this.health,
    required this.documents,
    required this.notificationsApi,
    required this.reminders,
    required this.settings,
    required this.syncService,
    required this.scheduler,
  });

  final ApiClient apiClient;
  final AuthState authState;
  final AuthStorage authStorage;

  final DashboardController dashboard;
  final PlannerController planner;
  final ProfileController profile;
  final DietController diet;
  final HabitsController habits;
  final FinanceController finance;
  final HealthRepository health;
  final DocumentsProvider documents;

  final NotificationsApi notificationsApi;
  final RemindersController reminders;
  final SettingsController settings;
  final ReminderSyncService syncService;
  final NotificationScheduler scheduler;

  /// Builds the production graph. Tests construct controllers directly.
  static Future<AppDependencies> create({
    String? baseUrl,
    AuthStorage? storage,
    NotificationScheduler? scheduler,
  }) async {
    final resolvedBase = baseUrl ?? AppConfig.apiBaseUrl;
    final authStorage = storage ?? AuthStorage();
    final apiClient = ApiClient(baseUrl: resolvedBase);
    final authState = AuthState(apiClient: apiClient, storage: authStorage);
    apiClient.onUnauthorized = authState.handleUnauthorized;
    await authState.restore();

    final dashboard =
        DashboardController(api: DashboardApi(apiClient: apiClient));
    Future<void> refreshDashboard() => dashboard.refresh(
          date: DateTime.now(),
          offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        );
    final planner = PlannerController(PlannerApi(apiClient));
    final profile = ProfileController(apiClient);
    final diet = DietController(
      HttpDietApi(apiClient),
      onUnauthorized: () => authState.handleUnauthorized(),
      // Diet owns food/water data; Home and Planner aggregate it, so they
      // refresh from the same dashboard payload after every mutation.
      onMutated: refreshDashboard,
    );
    final habits = HabitsController(
      api: HabitsApi(apiClient: apiClient),
      // Habits own habit + occurrence data; Home and Planner aggregate it,
      // so they refresh from the same dashboard payload after every mutation.
      onMutated: refreshDashboard,
    );
    final finance = FinanceController(
      api: FinanceApi(apiClient: apiClient),
      // Finance owns all finance data; Home and Planner aggregate it, so
      // they refresh from the same dashboard payload after every mutation.
      onMutated: refreshDashboard,
    );
    final health = HealthRepository(HealthApi(apiClient));
    final documents =
        DocumentsProvider(DocumentsRepository(apiClient));

    final effectiveScheduler =
        scheduler ?? FlutterNotificationScheduler();
    final legacyTokens = TokenStore.secured(authStorage);
    await legacyTokens.load();
    final notificationsClient = BlistraApiClient(
      baseUrl: resolvedBase,
      tokenStore: legacyTokens,
      tokenProvider: () => apiClient.token,
      onUnauthorized: () => authState.handleUnauthorized(),
    );
    final notificationsApi = NotificationsApi(notificationsClient);
    final syncService = ReminderSyncService(
      api: notificationsApi,
      scheduler: effectiveScheduler,
      tokens: legacyTokens,
    );
    final reminders = RemindersController(api: notificationsApi);
    final settings = SettingsController(
      api: notificationsApi,
      syncService: syncService,
    );

    // Keep the legacy token cache in step with the secure session.
    authState.addListener(() {
      legacyTokens.prime(apiClient.token);
    });

    return AppDependencies._(
      apiClient: apiClient,
      authState: authState,
      authStorage: authStorage,
      dashboard: dashboard,
      planner: planner,
      profile: profile,
      diet: diet,
      habits: habits,
      finance: finance,
      health: health,
      documents: documents,
      notificationsApi: notificationsApi,
      reminders: reminders,
      settings: settings,
      syncService: syncService,
      scheduler: effectiveScheduler,
    );
  }
}
