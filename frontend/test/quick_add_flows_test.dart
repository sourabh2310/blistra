/// Every Quick Add action must open its creation screen inside the real app
/// dependency graph (providers above the Navigator) without throwing.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/app/app_dependencies.dart';
import 'package:frontend/core/widgets/quick_add.dart';
import 'package:frontend/features/auth/auth_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final action in quickAddActions) {
    testWidgets('Quick Add "${action.label}" opens its form', (tester) async {
      final deps = (await tester.runAsync(
        () => AppDependencies.create(baseUrl: 'http://localhost:9'),
      ))!;
      await tester.pumpWidget(BlistraApp(deps: deps));
      await tester.pump(const Duration(milliseconds: 300));

      final context = tester.element(find.byType(AuthScreen));
      final navigator = Navigator.of(context);
      var routes = 0;
      navigator.popUntil((route) {
        routes++;
        return true;
      });

      // ignore: discarded_futures
      openQuickAddCreation(context, action);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull, reason: '${action.label} threw while opening');
      // A route (page or sheet) was pushed above the auth screen.
      expect(find.byType(AuthScreen, skipOffstage: false), findsOneWidget);
      expect(navigator.canPop(), isTrue, reason: '${action.label} did not open anything');
      expect(routes, 1);
    });
  }
}
