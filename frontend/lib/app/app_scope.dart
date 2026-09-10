/// Global application scope: auth session plus the two controllers that the
/// existing dashboard/planner screens already consume via `AppScope.of`.
///
/// Other features resolve their own controllers through `provider` (see
/// [AppShell]), so this scope stays small on purpose: it only exists to fix
/// the missing `features/app_scope.dart` import that currently breaks
/// compilation, and to give the shell a single session object.
library;

import 'package:flutter/widgets.dart';

import '../core/auth/auth_state.dart';
import '../features/dashboard/dashboard_controller.dart';
import '../features/planner/planner_controller.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.authState,
    required this.dashboard,
    required this.planner,
    required super.child,
  });

  final AuthState authState;

  /// Alias kept for screens that read `scope.auth`.
  AuthState get auth => authState;

  final DashboardController dashboard;
  final PlannerController planner;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw StateError('AppScope is missing from the widget tree');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.authState != authState ||
      oldWidget.dashboard != dashboard ||
      oldWidget.planner != planner;
}
