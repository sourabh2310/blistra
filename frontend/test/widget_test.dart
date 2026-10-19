import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/app/app_dependencies.dart';
import 'package:frontend/features/auth/auth_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // create() does real async I/O (storage, plugin channels), which never
  // completes inside the widget tester's fake-async zone.
  Future<AppDependencies> buildDeps(WidgetTester tester) async =>
      (await tester.runAsync(
        () => AppDependencies.create(baseUrl: 'http://localhost:8080'),
      ))!;

  group('BlistraApp auth gate', () {
    testWidgets('Shows login when unauthenticated', (tester) async {
      final deps = await buildDeps(tester);
      await tester.pumpWidget(BlistraApp(deps: deps));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Login form validates empty fields', (tester) async {
      final deps = await buildDeps(tester);
      await tester.pumpWidget(
        MaterialApp(home: AuthScreen(deps: deps)),
      );

      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Enter your username, email or phone'), findsOneWidget);
    });

    testWidgets('Toggle switches to register mode', (tester) async {
      final deps = await buildDeps(tester);
      await tester.pumpWidget(
        MaterialApp(home: AuthScreen(deps: deps)),
      );

      // New UI: sign-in screen has a "Create account" link in the nav bar
      final toggle = find.text('Create account');
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();

      // After tapping, we land on the welcome screen (register flow)
      expect(find.text('Get started'), findsOneWidget);
    });
  });
}
