/// Shell ownership tests: root provider scope survives pushed routes, and
/// every module page builds without ProviderNotFoundException.
///
/// Uses hand-built controllers over a mocked HTTP layer (no
/// AppDependencies.create, no real sockets): the regression under test is
/// scope placement (providers above MaterialApp), which this file mirrors
/// exactly, plus per-module dependency availability on pushed routes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app_scope.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/core/routing/routes.dart';
import 'package:frontend/core/widgets/module_guard.dart';
import 'package:frontend/features/dashboard/dashboard_api.dart';
import 'package:frontend/features/dashboard/dashboard_controller.dart';
import 'package:frontend/features/diet/diet_api.dart';
import 'package:frontend/features/diet/diet_controller.dart';
import 'package:frontend/features/diet/screens/today_screen.dart' as diet;
import 'package:frontend/features/documents/documents_page.dart';
import 'package:frontend/features/documents/providers/documents_provider.dart';
import 'package:frontend/features/documents/repositories/documents_repository.dart';
import 'package:frontend/features/finance/finance_api.dart';
import 'package:frontend/features/finance/finance_controller.dart';
import 'package:frontend/features/finance/finance_home.dart';
import 'package:frontend/features/finance/finance_scope.dart';
import 'package:frontend/features/habits/habits_api.dart';
import 'package:frontend/features/habits/habits_controller.dart';
import 'package:frontend/features/habits/habits_home.dart';
import 'package:frontend/features/habits/habits_scope.dart';
import 'package:frontend/features/health/health_api.dart';
import 'package:frontend/features/health/health_repository.dart';
import 'package:frontend/features/health/presentation/health_home_screen.dart';
import 'package:frontend/features/medicines/pages/medicine_list_page.dart';
import 'package:frontend/features/notifications/api/blistra_api_client.dart';
import 'package:frontend/features/notifications/api/notifications_api.dart';
import 'package:frontend/features/notifications/api/token_store.dart';
import 'package:frontend/features/notifications/models/scheduled_notification.dart';
import 'package:frontend/features/notifications/screens/notification_settings_screen.dart';
import 'package:frontend/features/notifications/screens/reminders_screen.dart';
import 'package:frontend/features/notifications/services/notification_scheduler.dart';
import 'package:frontend/features/notifications/services/reminder_sync_service.dart';
import 'package:frontend/features/notifications/state/reminders_controller.dart';
import 'package:frontend/features/notifications/state/settings_controller.dart';
import 'package:frontend/features/planner/planner_api.dart';
import 'package:frontend/features/planner/planner_controller.dart';
import 'package:frontend/features/profile/profile_controller.dart';

class _FakeScheduler implements NotificationScheduler {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule(ScheduledNotification notification) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> cancelMany(Iterable<int> ids) async {}
}

class _Scope {
  late final ApiClient api;
  late final AuthState auth;
  late final DashboardController dashboard;
  late final PlannerController planner;
  late final ProfileController profile;
  late final DietController diet;
  late final HabitsController habits;
  late final FinanceController finance;
  late final HealthRepository health;
  late final DocumentsProvider documents;
  late final RemindersController reminders;
  late final SettingsController settings;
}

_Scope _buildScope() {
  final mock = MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/reminders')) {
      return http.Response('[]', 200);
    }
    if (path.endsWith('/preferences')) {
      return http.Response(
          '{"enabled":true,"medicineEnabled":true,"habitEnabled":true,'
          '"plannerEnabled":true,"healthEnabled":true,"generalEnabled":true,'
          '"hideSensitiveContent":false}',
          200);
    }
    return http.Response('{}', 200);
  });
  final scope = _Scope();
  scope.api = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mock);
  scope.auth = AuthState(apiClient: scope.api, storage: AuthStorage());
  scope.dashboard = DashboardController(api: DashboardApi(apiClient: scope.api));
  scope.planner = PlannerController(PlannerApi(scope.api));
  scope.profile = ProfileController(scope.api);
  scope.diet = DietController(HttpDietApi(scope.api),
      onUnauthorized: () async {}, onMutated: () async {});
  scope.habits = HabitsController(api: HabitsApi(apiClient: scope.api));
  scope.finance = FinanceController(api: FinanceApi(apiClient: scope.api));
  scope.health = HealthRepository(HealthApi(scope.api));
  scope.documents = DocumentsProvider(DocumentsRepository(scope.api));
  final notificationsClient = BlistraApiClient(
    baseUrl: 'http://localhost:8080',
    httpClient: mock,
    tokenStore: TokenStore.secured(AuthStorage()),
  );
  final notificationsApi = NotificationsApi(notificationsClient);
  final sync = ReminderSyncService(
    api: notificationsApi,
    scheduler: _FakeScheduler(),
    tokens: TokenStore.secured(AuthStorage()),
  );
  scope.reminders = RemindersController(api: notificationsApi);
  scope.settings =
      SettingsController(api: notificationsApi, syncService: sync);
  return scope;
}

/// Mirrors BlistraApp's root scope: AppScope + providers ABOVE MaterialApp so
/// pushed routes inherit the same instances.
Widget _rootScope(_Scope scope, Widget home) {
  return AppScope(
    authState: scope.auth,
    dashboard: scope.dashboard,
    planner: scope.planner,
    child: MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: scope.api),
        ChangeNotifierProvider<AuthState>.value(value: scope.auth),
        ChangeNotifierProvider<DashboardController>.value(
            value: scope.dashboard),
        ChangeNotifierProvider<PlannerController>.value(value: scope.planner),
        ChangeNotifierProvider<ProfileController>.value(value: scope.profile),
        ChangeNotifierProvider<DietController>.value(value: scope.diet),
        ChangeNotifierProvider<HabitsController>.value(value: scope.habits),
        ChangeNotifierProvider<FinanceController>.value(value: scope.finance),
        ChangeNotifierProvider<HealthRepository>.value(value: scope.health),
        ChangeNotifierProvider<DocumentsProvider>.value(
            value: scope.documents),
        ChangeNotifierProvider<RemindersController>.value(
            value: scope.reminders),
        ChangeNotifierProvider<SettingsController>.value(
            value: scope.settings),
      ],
      child: MaterialApp(home: home),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('pushed routes inherit every module dependency', (tester) async {
    final scope = _buildScope();
    Object? probeError;
    await tester.pumpWidget(_rootScope(
      scope,
      Builder(
        builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => Builder(
                  builder: (context) {
                    try {
                      context.read<AuthState>();
                      context.read<DashboardController>();
                      context.read<PlannerController>();
                      context.read<ProfileController>();
                      context.read<DietController>();
                      context.read<HabitsController>();
                      context.read<FinanceController>();
                      context.read<HealthRepository>();
                      context.read<DocumentsProvider>();
                      context.read<RemindersController>();
                      context.read<SettingsController>();
                      AppScope.of(context);
                    } catch (e) {
                      probeError = e;
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            );
          });
          return const SizedBox.shrink();
        },
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(probeError, isNull,
        reason: 'root scope must serve every module dependency');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Medicines page builds without ProviderNotFoundException',
      (tester) async {
    final scope = _buildScope();
    await tester.pumpWidget(
        _rootScope(scope, const MedicineListPage()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MedicineListPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Diet page builds without ProviderNotFoundException',
      (tester) async {
    final scope = _buildScope();
    await tester.pumpWidget(
        _rootScope(scope, const diet.TodayScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(diet.TodayScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Documents page builds without ProviderNotFoundException',
      (tester) async {
    final scope = _buildScope();
    await tester.pumpWidget(
        _rootScope(scope, const DocumentsPage()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(DocumentsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reminders + settings build without ProviderNotFoundException',
      (tester) async {
    final scope = _buildScope();
    await tester.pumpWidget(_rootScope(
      scope,
      RemindersScreen(onRefresh: () async {}),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(RemindersScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Production wraps bare settings content in a Scaffold (ownAppBar:false);
    // mirror that here: ListTile content needs a Material ancestor.
    await tester.pumpWidget(_rootScope(
      scope,
      Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: NotificationSettingsScreen(onRefresh: () async {}),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Habits + Finance build with their explicit scopes',
      (tester) async {
    final scope = _buildScope();
    await tester.pumpWidget(_rootScope(
      scope,
      HabitsScope(controller: scope.habits, child: const HabitsHome()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HabitsHome), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_rootScope(
      scope,
      FinanceScope(controller: scope.finance, child: const FinanceHome()),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(FinanceHome), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Health builds with repository + root AppScope', (tester) async {
    final scope = _buildScope();
    await tester.pumpWidget(_rootScope(
      scope,
      HealthHomeScreen(repository: scope.health, onLogout: () async {}),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HealthHomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ModuleErrorScreen offers Back without crashing',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ModuleErrorScreen(title: 'T', message: 'M')),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ModulePlaceholder renders coming-soon state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ModulePlaceholder(
          title: 'Docs',
          description: 'Soon.',
          icon: Icons.folder_outlined,
        ),
      ),
    );
    expect(find.text('Coming soon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('AppRoutes.resolveSearchRoute', () {
    test('medicines detail resolves', () {
      final dest = AppRoutes.resolveSearchRoute('medicines/abc');
      expect(dest.detail, isNotNull);
    });

    test('unknown routes fall back to dashboard, never a dead end', () {
      final dest = AppRoutes.resolveSearchRoute('nonsense/xyz');
      expect(dest.tab, AppTab.dashboard);
      expect(dest.detail, isNull);
    });

    test('Planner task event and list search routes open owned details', () {
      for (final route in ['planner/task/abc', 'planner/event/abc', 'planner/list/abc']) {
        final dest = AppRoutes.resolveSearchRoute(route);
        expect(dest.tab, AppTab.planner);
        expect(dest.detail, isNotNull);
      }
    });

    test('documents resolve by id without switching tabs', () {
      final dest = AppRoutes.resolveSearchRoute('documents/doc-1');
      expect(dest.documentId, 'doc-1');
    });
  });
}
