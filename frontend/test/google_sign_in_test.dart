import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
  late List<http.Request> registrationRequests;
  late int googleStatus;
  // What the backend reports for the Google identity: a brand-new account
  // (registration needed) or an existing, fully set-up one.
  late bool newGoogleUser;

  Map<String, dynamic> accountJson({required bool onboarded}) => {
    'id': 'u-1',
    'userId': 'u-1',
    'username': 'jane.doe',
    'email': 'jane@example.com',
    'emailVerified': true,
    'phoneVerified': false,
    'onboardingCompleted': onboarded,
    'status': 'ACTIVE',
  };

  Future<AppDependencies> buildDeps(WidgetTester tester) async {
    googleRequests = [];
    registrationRequests = [];
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/profile' && request.method == 'GET') {
        return http.Response(
          jsonEncode(accountJson(onboarded: !newGoogleUser)),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/profile/google-registration') {
        registrationRequests.add(request);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            ...accountJson(onboarded: false),
            'username': body['username'],
            'displayName': body['displayName'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
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
            'user': accountJson(onboarded: !newGoogleUser),
            'newUser': newGoogleUser,
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

  setUp(() {
    googleStatus = 200;
    newGoogleUser = false;
  });

  // An unsigned ID token carrying Google's name claims (pre-fill only).
  String idTokenWithName() {
    String part(Map<String, Object> json) =>
        base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
    return '${part({'alg': 'RS256'})}.'
        '${part({'sub': '1', 'given_name': 'Jane', 'family_name': 'Doe'})}.sig';
  }

  testWidgets('a new Google user finishes registration without email or password', (
    tester,
  ) async {
    newGoogleUser = true;
    final deps = await buildDeps(tester);
    final google = _FakeGoogle(token: idTokenWithName());
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(deps: deps, googleTokenProvider: google)),
    );

    await tapGoogle(tester, settled: () => deps.authState.isAuthenticated);
    await tester.pumpAndSettle();

    expect(deps.authState.justRegistered, isTrue);
    expect(find.text('Just a few more details.'), findsOneWidget);
    expect(find.text('Verified by Google'), findsOneWidget);
    expect(find.text('jane@example.com'), findsOneWidget);
    expect(find.text('PASSWORD'), findsNothing);
    expect(find.text('CONFIRM PASSWORD'), findsNothing);
    expect(find.widgetWithText(TextField, 'Jane'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Doe'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'jane.doe'), findsOneWidget);

    final submit = find.text('Continue');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.runAsync(() async {
      for (var i = 0; i < 40 && registrationRequests.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    expect(registrationRequests, hasLength(1));
    expect(jsonDecode(registrationRequests.single.body), {
      'displayName': 'Jane Doe',
      'username': 'jane.doe',
    });
    expect(find.text('Complete profile →'), findsOneWidget);
  });

  testWidgets('a returning Google user skips registration', (tester) async {
    final deps = await buildDeps(tester);
    final google = _FakeGoogle(token: idTokenWithName());
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(deps: deps, googleTokenProvider: google)),
    );

    await tapGoogle(tester, settled: () => deps.authState.isAuthenticated);

    expect(deps.authState.isAuthenticated, isTrue);
    expect(deps.authState.justRegistered, isFalse);
    expect(deps.authState.needsOnboarding, isFalse);
    expect(find.text('Just a few more details.'), findsNothing);
    expect(registrationRequests, isEmpty);
  });

  test('an OAuth client misconfiguration is not treated as a dismissal', () {
    expect(
      GoogleSignInService.isUserCancellation(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: 'activity is cancelled by the user.',
        ),
      ),
      isTrue,
    );
    expect(
      GoogleSignInService.isUserCancellation(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: '[16] Account reauth failed.',
        ),
      ),
      isFalse,
    );
  });

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
