/// Central dependency graph for the Blistra app.
///
/// Replaces the notifications-owned `AppDependencies`: the session, HTTP
/// client and every feature controller are built here once, from [AppConfig],
/// and exposed to the widget tree by [AppShell] (via [AppScope] + `provider`).
///
/// Local notifications are wired but never initialized here and permissions
/// are never requested at startup — see [AppShell] / settings.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import 'package:http/http.dart' as http;

import '../core/api/api_client.dart';
import '../core/auth/auth_state.dart';
import '../core/auth/auth_storage.dart';
import '../core/config/app_config.dart';
import '../core/theme/theme_controller.dart';
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
import '../features/preferences/preferences_api.dart';
import '../features/preferences/preferences_controller.dart';
import '../features/app_update/app_update_controller.dart';
import '../features/profile/profile_controller.dart';

class AppDependencies {
  AppDependencies._({
    required this.apiClient,
    required this.authState,
    required this.authStorage,
    required this.dashboard,
    required this.planner,
    required this.preferences,
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
    required this.theme,
    required this.appUpdate,
  });

  final ApiClient apiClient;
  final AuthState authState;
  final AuthStorage authStorage;

  DashboardController dashboard;
  PlannerController planner;
  PreferencesController preferences;
  ProfileController profile;
  DietController diet;
  HabitsController habits;
  FinanceController finance;
  HealthRepository health;
  DocumentsProvider documents;

  NotificationsApi notificationsApi;
  RemindersController reminders;
  SettingsController settings;
  ReminderSyncService syncService;
  final NotificationScheduler scheduler;
  final ThemeController theme;
  final AppUpdateController appUpdate;

  /// Builds the production graph. Tests construct controllers directly.
  static Future<AppDependencies> create({
    String? baseUrl,
    AuthStorage? storage,
    NotificationScheduler? scheduler,
    http.Client? httpClient,
  }) async {
    final resolvedBase = baseUrl ?? AppConfig.apiBaseUrl;
    final authStorage = storage ?? AuthStorage();
    final apiClient = ApiClient(baseUrl: resolvedBase, httpClient: httpClient);
    // Wake a sleeping free-tier backend while the app starts.
    unawaited(apiClient.warmUp());
    final theme = ThemeController();
    await theme.load();
    final authState = AuthState(apiClient: apiClient, storage: authStorage);
    apiClient.onUnauthorized = authState.handleUnauthorized;
    await authState.restore();

    final effectiveScheduler = scheduler ?? FlutterNotificationScheduler();
    final legacyTokens = TokenStore.secured(authStorage);
    await legacyTokens.load();
    final deps = _session(
      apiClient,
      authState,
      authStorage,
      theme,
      effectiveScheduler,
      legacyTokens,
    );
    authState.onSessionEnded = () async {
      final previousSync = deps.syncService;
      final fresh = _session(
        apiClient,
        authState,
        authStorage,
        theme,
        effectiveScheduler,
        legacyTokens,
      );
      deps.dashboard = fresh.dashboard;
      deps.planner = fresh.planner;
      deps.preferences = fresh.preferences;
      deps.profile = fresh.profile;
      deps.diet = fresh.diet;
      deps.habits = fresh.habits;
      deps.finance = fresh.finance;
      deps.health = fresh.health;
      deps.documents = fresh.documents;
      deps.notificationsApi = fresh.notificationsApi;
      deps.reminders = fresh.reminders;
      deps.settings = fresh.settings;
      deps.syncService = fresh.syncService;
      try {
        await previousSync.clearAll();
      } finally {
        if (!kIsWeb) {
          final temp = await getTemporaryDirectory();
          final previews = Directory('${temp.path}/blistra-document-previews');
          if (await previews.exists()) await previews.delete(recursive: true);
        }
      }
    };
    authState.addListener(() => legacyTokens.prime(apiClient.token));
    return deps;
  }

  // Controllers belong to one account session. Replacing this graph makes
  // late responses unreachable from the next account's widget tree.
  static AppDependencies _session(
    ApiClient apiClient,
    AuthState authState,
    AuthStorage authStorage,
    ThemeController theme,
    NotificationScheduler effectiveScheduler,
    TokenStore legacyTokens,
  ) {
    final resolvedBase = apiClient.baseUrl;

    final dashboard = DashboardController(
      api: DashboardApi(apiClient: apiClient),
    );
    Future<void> refreshDashboard() => dashboard.refresh(
      date: DateTime.now(),
      offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
    );
    late final PlannerController planner;
    final preferences = PreferencesController(PreferencesApi(apiClient));
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
    final documents = DocumentsProvider(DocumentsRepository(apiClient));

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
    final reminders = RemindersController(
      api: notificationsApi,
      onChanged: syncService.refresh,
    );
    final profile = ProfileController(
      apiClient,
      onTimezoneChanged: () async {
        await syncService.refresh();
        await refreshDashboard();
        await planner.loadToday();
      },
    );
    final settings = SettingsController(
      api: notificationsApi,
      syncService: syncService,
    );
    planner = PlannerController(
      PlannerApi(apiClient),
      onRemindersChanged: () async {
        await syncService.refresh();
        await reminders.load();
      },
      onDashboardChanged: refreshDashboard,
    );

    return AppDependencies._(
      apiClient: apiClient,
      authState: authState,
      authStorage: authStorage,
      dashboard: dashboard,
      planner: planner,
      preferences: preferences,
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
      theme: theme,
      appUpdate: AppUpdateController(apiClient),
    );
  }
}
