/// Application root: theme, root-scoped dependencies, auth gate, shell.
///
/// [AppScope] and the `provider` graph live ABOVE [MaterialApp] on purpose:
/// every route pushed on the root [Navigator] (all module pages opened from
/// Modules) must resolve the same application-wide [AuthState] and feature
/// controllers. Scoping providers inside [AppShell] puts pushed routes above
/// the providers and produces ProviderNotFoundException (seen on
/// MedicineListPage). There is exactly one [AuthState] instance: [deps].
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_state.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../features/auth/auth_screen.dart';
import '../features/dashboard/dashboard_controller.dart';
import '../features/diet/diet_controller.dart';
import '../features/documents/providers/documents_provider.dart';
import '../features/finance/finance_controller.dart';
import '../features/habits/habits_controller.dart';
import '../features/health/health_repository.dart';
import '../features/notifications/state/reminders_controller.dart';
import '../features/notifications/state/settings_controller.dart';
import '../features/planner/planner_controller.dart';
import '../features/preferences/preferences_controller.dart';
import '../features/profile/profile_controller.dart';
import 'app_dependencies.dart';
import 'app_scope.dart';
import 'app_shell.dart';

class BlistraApp extends StatelessWidget {
  const BlistraApp({super.key, required this.deps});

  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    // Root scope: session + every feature controller, once, above the
    // Navigator so pushed module routes inherit them.
    return AppScope(
      authState: deps.authState,
      dashboard: deps.dashboard,
      planner: deps.planner,
      child: MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: deps.apiClient),
          ChangeNotifierProvider<AuthState>.value(value: deps.authState),
          ChangeNotifierProvider<ThemeController>.value(value: deps.theme),
          ChangeNotifierProvider<DashboardController>.value(
              value: deps.dashboard),
          ChangeNotifierProvider<PlannerController>.value(value: deps.planner),
          ChangeNotifierProvider<PreferencesController>.value(
              value: deps.preferences),
          ChangeNotifierProvider<ProfileController>.value(value: deps.profile),
          ChangeNotifierProvider<DietController>.value(value: deps.diet),
          ChangeNotifierProvider<HabitsController>.value(value: deps.habits),
          ChangeNotifierProvider<FinanceController>.value(value: deps.finance),
          ChangeNotifierProvider<HealthRepository>.value(value: deps.health),
          ChangeNotifierProvider<DocumentsProvider>.value(
              value: deps.documents),
          ChangeNotifierProvider<RemindersController>.value(
              value: deps.reminders),
          ChangeNotifierProvider<SettingsController>.value(
              value: deps.settings),
        ],
        child: ListenableBuilder(
          listenable: deps.theme,
          builder: (context, _) => MaterialApp(
            title: 'Blistra',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: deps.theme.mode,
            home: AuthGate(deps: deps),
          ),
        ),
      ),
    );
  }
}

/// Routes to login or the shell based on [AuthState].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.deps});

  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.authState,
      builder: (context, _) {
        if (deps.authState.status == AuthStatus.unknown ||
            deps.authState.status == AuthStatus.busy) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (deps.authState.isAuthenticated) {
          // Fresh registrations stay in the onboarding wizard until profile
          // setup completes; everyone else lands on the shell (Profile
          // surfaces any pending verification from there).
          if (deps.authState.justRegistered &&
              deps.authState.needsOnboarding) {
            return AuthScreen(deps: deps, startWizard: true);
          }
          return AppShell(deps: deps);
        }
        return AuthScreen(deps: deps);
      },
    );
  }
}
