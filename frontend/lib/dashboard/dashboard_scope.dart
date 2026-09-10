/// Inherited access to the Dashboard controller.
library;

import 'package:flutter/widgets.dart';

import 'dashboard_controller.dart';

class DashboardScope extends InheritedNotifier<DashboardController> {
  const DashboardScope({
    super.key,
    required DashboardController controller,
    required super.child,
  }) : super(notifier: controller);

  static DashboardController of(BuildContext context) {
    final DashboardScope? scope =
        context.dependOnInheritedWidgetOfExactType<DashboardScope>();
    if (scope == null) {
      throw StateError('DashboardScope is missing from the widget tree');
    }
    final DashboardController? controller = scope.notifier;
    if (controller == null) {
      throw StateError('DashboardScope has no controller');
    }
    return controller;
  }
}