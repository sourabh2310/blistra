import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/main.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/features/medicines/data/medicines_api_client.dart';

void main() {
  testWidgets('Blistra app shows login page when unauthenticated', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      // Return 401 for any auth endpoint (unauthenticated)
      return http.Response('{"code":"UNAUTHORIZED","message":"Invalid credentials"}', 401);
    });

    final apiClient = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockClient);
    final authState = AuthState(apiClient: apiClient);

    await tester.pumpWidget(
      AppScope(
        apiClient: apiClient,
        authState: authState,
        medicinesApiClient: MedicinesApiClient(
          httpClient: mockClient,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => '',
        ),
        child: const BlistraApp(),
      ),
    );

    // Should show login page
    expect(find.text('Blistra'), findsOneWidget);
    expect(find.text('Everything you need. One app.'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2)); // email + password
  });

  testWidgets('Login form validation works', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response('{"code":"UNAUTHORIZED","message":"Invalid credentials"}', 401);
    });

    final apiClient = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockClient);
    final authState = AuthState(apiClient: apiClient);

    await tester.pumpWidget(
      AppScope(
        apiClient: apiClient,
        authState: authState,
        medicinesApiClient: MedicinesApiClient(
          httpClient: mockClient,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => '',
        ),
        child: const BlistraApp(),
      ),
    );

    // Try to submit empty form
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    // Fill email only
    await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('Toggle to register mode shows confirm password', (WidgetTester tester) async {
    final mockClient = MockClient((request) async {
      return http.Response('{"code":"UNAUTHORIZED","message":"Invalid credentials"}', 401);
    });

    final apiClient = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mockClient);
    final authState = AuthState(apiClient: apiClient);

    await tester.pumpWidget(
      AppScope(
        apiClient: apiClient,
        authState: authState,
        medicinesApiClient: MedicinesApiClient(
          httpClient: mockClient,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => '',
        ),
        child: const BlistraApp(),
      ),
    );

    // Toggle to register
    await tester.tap(find.text('Register'));
    await tester.pump();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3)); // email + password + confirm
  });
}