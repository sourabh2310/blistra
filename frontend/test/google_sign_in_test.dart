import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app_dependencies.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/core/auth/google_sign_in_service.dart';
import 'package:frontend/features/auth/auth_screen.dart';

class _FakeGoogle implements GoogleIdTokenProvider {
  _FakeGoogle({this.token, this.error});

  final String? token;
  final Object? error;
  int calls = 0;

  @override
  Future<String?> getIdToken() async {
    calls++;
    if (error != null) throw error!;
    return token;
  }
}

class _MemoryStorage extends AuthStorage {
  String? token;
  String? email;

  @override
  Future<String?> readToken() async => token;

  @override
  Future<String?> readEmail() async => email;

  @override
  Future<void> saveSession({required String token, required String email}) async {
    this.token = token;
    this.email = email;
  }

  @override
  Future<void> clear() async {
    token = null;
    email = null;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late List<http.Request> googleRequests;
  late int googleStatus;

  Future<AppDependencies> buildDeps(WidgetTester tester) async {
    googleRequests = [];
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/auth/google') {
        googleRequests.add(request);
        if (googleStatus != 200) {
          return http.Response(
            jsonEncode({'code': 'UNAUTHORIZED', 'message': 'nope'}),
            googleStatus,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'token': 'jwt-token',
            'tokenType': 'Bearer',
            'user': {'email': 'jane@example.com'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('{}', 200);
    });
    return (await tester.runAsync(
      () => AppDependencies.create(
        baseUrl: 'http://localhost:8080',
        storage: _MemoryStorage(),
        httpClient: client,
      ),
    ))!;
  }

  Future<void> tapGoogle(
    WidgetTester tester, {
    bool Function()? settled,
  }) async {
    final button = find.text('Continue with Google');
    await tester.ensureVisible(button);
    await tester.tap(button);
    // Storage and plugin channels complete in real time, not fake time.
    await tester.runAsync(() async {
      for (var i = 0; i < 40; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        if (settled == null ? i >= 5 : settled()) return;
      }
    });
    await tester.pump();
  }

  setUp(() => googleStatus = 200);

  testWidgets('sends the Google ID token to the backend and signs in', (
    tester,
  ) async {
    final deps = await buildDeps(tester);
    final google = _FakeGoogle(token: 'google-id-token');
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(deps: deps, googleTokenProvider: google)),
    );

    await tapGoogle(tester, settled: () => deps.authState.isAuthenticated);

    expect(google.calls, 1);
    expect(googleRequests, hasLength(1));
    expect(jsonDecode(googleRequests.single.body), {
      'idToken': 'google-id-token',
      'termsAccepted': true,
    });
    expect(
      deps.authState.isAuthenticated,
      isTrue,
      reason: 'status=${deps.authState.status} error=${deps.authState.lastError}',
    );
    expect(deps.apiClient.token, 'jwt-token');
  });

  testWidgets('does nothing when the user dismisses the account picker', (
    tester,
  ) async {
    final deps = await buildDeps(tester);
    final google = _FakeGoogle(token: null);
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(deps: deps, googleTokenProvider: google)),
    );

    await tapGoogle(tester);

    expect(google.calls, 1);
    expect(googleRequests, isEmpty);
    expect(deps.authState.isAuthenticated, isFalse);
    expect(find.textContaining("Couldn't sign in"), findsNothing);
  });

  testWidgets('shows a message when Google sign-in is unavailable', (
    tester,
  ) async {
    final deps = await buildDeps(tester);
    final google = _FakeGoogle(
      error: const GoogleSignInUnavailable("Google sign-in isn't set up."),
    );
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(deps: deps, googleTokenProvider: google)),
    );

    await tapGoogle(tester);

    expect(find.text("Google sign-in isn't set up."), findsOneWidget);
    expect(googleRequests, isEmpty);
  });

  testWidgets('shows a generic error when the backend rejects the token', (
    tester,
  ) async {
    googleStatus = 401;
    final deps = await buildDeps(tester);
    final google = _FakeGoogle(token: 'bad');
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(deps: deps, googleTokenProvider: google)),
    );

    await tapGoogle(tester);

    expect(find.text("Blistra couldn't verify your Google sign-in. Please try again."),
        findsOneWidget);
    expect(deps.authState.isAuthenticated, isFalse);
  });
}
