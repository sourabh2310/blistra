/// Focused tests for the premium auth components.
///
/// Widget pumps stay dependency-free ([OtpInput], [PasswordStrength]) so they
/// run without [AppDependencies]; AuthState/backend contracts are covered in
/// `registration_onboarding_test.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exception.dart';
import 'package:frontend/features/auth/auth_widgets.dart';

void main() {
  group('ApiClient.checkAvailability', () {
    test('sends only supplied fields and parses booleans', () async {
      Map<String, String>? query;
      final client = MockClient((request) async {
        query = request.url.queryParameters;
        return http.Response(
            '{"usernameAvailable":false,"emailAvailable":true}', 200);
      });
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        httpClient: client,
      )..token = 't';
      final result = await api.checkAvailability(
        username: 'takenuser',
        email: 'free@example.com',
      );
      expect(query?['username'], 'takenuser');
      expect(query?['email'], 'free@example.com');
      expect(query?.containsKey('phone'), isFalse);
      expect(result.usernameAvailable, isFalse);
      expect(result.emailAvailable, isTrue);
      expect(result.phoneAvailable, isNull);
    });
  });

  group('ApiClient.recoveryChannels', () {
    test('parses verified channels with masked destinations', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/recovery/channels');
        return http.Response(
            '{"channels":["EMAIL","SMS"],"emailMasked":"so***@example.com","phoneMasked":"***10"}',
            200);
      });
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        httpClient: client,
      )..token = 't';
      final result =
          await api.recoveryChannels(identifier: 'sourabh');
      expect(result.offersEmail, isTrue);
      expect(result.offersSms, isTrue);
      expect(result.emailMasked, 'so***@example.com');
      expect(result.emailMasked, isNot(contains('sourabh')));
    });

    test('unknown identifier surfaces 404', () async {
      final client = MockClient((request) async {
        return http.Response(
            '{"status":404,"code":"RESOURCE_NOT_FOUND","message":"Couldn\'t find an account with those details."}',
            404);
      });
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        httpClient: client,
      )..token = 't';
      try {
        await api.recoveryChannels(identifier: 'ghostuser');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 404);
        expect(e.message, contains("Couldn't find an account"));
      }
    });
  });

  group('OtpInput', () {
    testWidgets('typing six digits fires onCompleted', (tester) async {
      final controller = TextEditingController();
      var completed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInput(
              controller: controller,
              onCompleted: () => completed++,
            ),
          ),
        ),
      );
      for (int i = 0; i < 6; i++) {
        await tester.enterText(
            find.byType(TextField).at(i), '${i + 1}');
        await tester.pump();
      }
      expect(controller.text, '123456');
      expect(completed, greaterThanOrEqualTo(1));
    });

    testWidgets('backspace on empty cell moves focus back', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: OtpInput(controller: controller)),
        ),
      );
      await tester.enterText(find.byType(TextField).at(0), '1');
      await tester.pump();
      expect(controller.text, '1');
    });

    testWidgets('is disabled when enabled=false', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OtpInput(controller: controller, enabled: false),
          ),
        ),
      );
      final fields =
          tester.widgetList<TextField>(find.byType(TextField));
      expect(fields.every((f) => f.enabled == false), isTrue);
    });
  });

  group('PasswordStrength', () {
    testWidgets('empty password renders nothing', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PasswordStrength(password: '')),
        ),
      );
      expect(find.text('Weak'), findsNothing);
      expect(find.text('Strong'), findsNothing);
    });

    testWidgets('short password shows Weak', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PasswordStrength(password: 'abc')),
        ),
      );
      expect(find.text('Weak'), findsOneWidget);
    });

    testWidgets('long alphanumeric password shows Strong', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home:
              Scaffold(body: PasswordStrength(password: 'Blistra2026!ok')),
        ),
      );
      expect(find.text('Strong'), findsOneWidget);
    });
  });

  group('AuthPrimaryButton', () {
    testWidgets('busy shows spinner and blocks taps', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AuthPrimaryButton(
              label: 'Continue',
              busy: true,
              onPressed: () => tapped++,
            ),
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(tapped, 0);
    });
  });
}
