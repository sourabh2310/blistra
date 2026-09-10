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

  Future<AppDependencies> buildDeps() =>
      AppDependencies.create(baseUrl: 'http://localhost:8080');

  group('BlistraApp auth gate', () {
    testWidgets('Shows login when unauthenticated', (tester) async {
      final deps = await buildDeps();
      await tester.pumpWidget(BlistraApp(deps: deps));
      await tester.pumpAndSettle();

      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Login form validates empty fields', (tester) async {
      final deps = await buildDeps();
      await tester.pumpWidget(
        MaterialApp(home: AuthScreen(deps: deps)),
      );

      await tester.tap(find.text('Sign in'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Toggle switches to register mode', (tester) async {
      final deps = await buildDeps();
      await tester.pumpWidget(
        MaterialApp(home: AuthScreen(deps: deps)),
      );

      await tester.tap(find.text('New here? Create an account'));
      await tester.pump();

      expect(find.text('Create account'), findsOneWidget);
    });
  });
}
