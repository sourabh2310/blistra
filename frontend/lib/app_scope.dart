import 'package:flutter/widgets.dart';

import '../auth/auth_controller.dart';
import '../planner/planner_controller.dart';

/// Provides the app-wide [AuthController] and [PlannerController] to screens
/// without prop drilling. Constructed once in [BlistraApp].
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.auth,
    required this.planner,
    required super.child,
  });

  final AuthController auth;
  final PlannerController planner;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      auth != oldWidget.auth || planner != oldWidget.planner;
}