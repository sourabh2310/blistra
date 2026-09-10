/// Inherited access to the finance controllers.
///
/// Using [InheritedNotifier] the finance UI rebuilds whenever the controller
/// notifies, without any third-party state management.
library;

import 'package:flutter/widgets.dart';

import '../../core/auth/auth_state.dart';
import 'finance_controller.dart';

class FinanceScope extends InheritedNotifier<FinanceController> {
  const FinanceScope({
    super.key,
    required FinanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static FinanceController of(BuildContext context) {
    final FinanceScope? scope =
        context.dependOnInheritedWidgetOfExactType<FinanceScope>();
    if (scope == null) {
      throw StateError('FinanceScope is missing from the widget tree');
    }
    final FinanceController? controller = scope.notifier;
    if (controller == null) {
      throw StateError('FinanceScope has no controller');
    }
    return controller;
  }
}

class AuthScope extends InheritedNotifier<AuthState> {
  const AuthScope({
    super.key,
    required AuthState auth,
    required super.child,
  }) : super(notifier: auth);

  static AuthState of(BuildContext context) {
    final AuthScope? scope =
        context.dependOnInheritedWidgetOfExactType<AuthScope>();
    if (scope == null) {
      throw StateError('AuthScope is missing from the widget tree');
    }
    final AuthState? auth = scope.notifier;
    if (auth == null) {
      throw StateError('AuthScope has no auth state');
    }
    return auth;
  }
}