/// Inherited access to the habits controllers.
///
/// Using [InheritedNotifier] the habits UI rebuilds whenever the controller
/// notifies, without any third-party state management.
library;

import 'package:flutter/widgets.dart';

import 'habits_controller.dart';

class HabitsScope extends InheritedNotifier<HabitsController> {
  const HabitsScope({
    super.key,
    required HabitsController controller,
    required super.child,
  }) : super(notifier: controller);

  static HabitsController of(BuildContext context) {
    final HabitsScope? scope =
        context.dependOnInheritedWidgetOfExactType<HabitsScope>();
    if (scope == null) {
      throw StateError('HabitsScope is missing from the widget tree');
    }
    final HabitsController? controller = scope.notifier;
    if (controller == null) {
      throw StateError('HabitsScope has no controller');
    }
    return controller;
  }
}