import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/app/app_dependencies.dart';
import 'package:frontend/app/app_shell.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/core/auth/google_sign_in_service.dart';
import 'package:frontend/features/profile/profile_screen.dart';

class _MemoryStorage extends AuthStorage {
  String? token = 'token';
  String? email = 'me@example.test';

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

class _FakeGoogle implements GoogleIdTokenProvider {
  _FakeGoogle({this.token, this.unavailable = false});

  final String? token;
  final bool unavailable;

  @override
  Future<String?> getIdToken() async {
    if (unavailable) throw const GoogleSignInUnavailable('not set up');
    return token;
  }
}

const _json = {'content-type': 'application/json'};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late List<http.Request> deleteRequests;
  late int deleteStatus;
  late bool googleLinked;

  Future<AppDependencies> buildDeps(WidgetTester tester) async {
    deleteRequests = [];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/v1/profile/delete-account') {
        deleteRequests.add(request);
        if (deleteStatus == 204) return http.Response('', 204);
        return http.Response(
          jsonEncode({
            'code': 'INVALID_CREDENTIALS',
            'message': 'Current password is incorrect',
          }),
          deleteStatus,
          headers: _json,
        );
      }
      if (path == '/api/v1/profile') {
        return http.Response(
          jsonEncode({
            'userId': 'me',
            'username': 'meuser',
            'email': 'me@example.test',
            'emailVerified': true,
            'phoneVerified': false,
            'onboardingCompleted': true,
            'status': 'ACTIVE',
            'displayName': 'Maya Rao',
            'country': 'IN',
            'timezone': 'Asia/Kolkata',
            'language': 'en',
            'unitSystem': 'METRIC',
            'allowFriendRequests': true,
            'hasAvatar': false,
            'googleLinked': googleLinked,
            'memberSince': '2026-03-01T10:00:00',
          }),
          200,
          headers: _json,
        );
      }
      return http.Response(
        jsonEncode({'code': 'UNAVAILABLE', 'message': 'Not in this test'}),
        503,
        headers: _json,
      );
    });
    return (await tester.runAsync(
      () => AppDependencies.create(
        baseUrl: 'http://backend.test',
        storage: _MemoryStorage(),
        httpClient: client,
      ),
    ))!;
  }

  // The login screen shown after sign-out overflows under the test font.
  void ignoreLoginLayoutOverflow(WidgetTester tester) {
    tester.takeException();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> openDeleteAccount(WidgetTester tester, AppDependencies deps) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(BlistraApp(deps: deps));
    await settle(tester);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.push(MaterialPageRoute(builder: (_) => const ProfileScreen()));
    await settle(tester);

    final scrollable = find
        .descendant(of: find.byType(ProfileScreen), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('Privacy & data'),
      200,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.text('Privacy & data'));
    await tester.pump();
    await tester.tap(find.text('Privacy & data'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Delete account'), 200);
    await tester.ensureVisible(find.text('Delete account'));
    await tester.pump();
    await tester.tap(find.text('Delete account'));
    await settle(tester);
  }

  setUp(() {
    deleteStatus = 204;
    googleLinked = false;
    googleIdTokenProvider = _FakeGoogle();
  });

  testWidgets('password account: confirms, sends the password and signs out', (
    tester,
  ) async {
    final deps = await buildDeps(tester);
    await openDeleteAccount(tester, deps);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.tap(find.text('Deactivate account'));
    await settle(tester);

    expect(deleteRequests, hasLength(1));
    expect(jsonDecode(deleteRequests.single.body), {'currentPassword': 'secret123'});
    expect(deps.authState.isAuthenticated, isFalse);
    expect(find.byType(AppShell), findsNothing);
    ignoreLoginLayoutOverflow(tester);
  });

  testWidgets('wrong password keeps the user signed in and shows the error', (
    tester,
  ) async {
    deleteStatus = 400;
    final deps = await buildDeps(tester);
    await openDeleteAccount(tester, deps);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('Deactivate account'));
    await settle(tester);

    expect(find.text('Current password is incorrect'), findsOneWidget);
    expect(deps.authState.isAuthenticated, isTrue);
  });

  testWidgets('google account re-authenticates with Google, no password', (
    tester,
  ) async {
    googleLinked = true;
    googleIdTokenProvider = _FakeGoogle(token: 'fresh-google-token');
    final deps = await buildDeps(tester);
    await openDeleteAccount(tester, deps);

    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(find.text('Deactivate account'), findsNothing);
    expect(deleteRequests, hasLength(1));
    expect(jsonDecode(deleteRequests.single.body), {
      'googleIdToken': 'fresh-google-token',
    });
    expect(deps.authState.isAuthenticated, isFalse);
    ignoreLoginLayoutOverflow(tester);
  });

  testWidgets('dismissing the Google picker cancels the deactivation', (
    tester,
  ) async {
    googleLinked = true;
    googleIdTokenProvider = _FakeGoogle(token: null);
    final deps = await buildDeps(tester);
    await openDeleteAccount(tester, deps);

    await tester.tap(find.text('Continue'));
    await settle(tester);

    expect(deleteRequests, isEmpty);
    expect(deps.authState.isAuthenticated, isTrue);
  });

  testWidgets('falls back to the password when Google is unavailable', (
    tester,
  ) async {
    googleLinked = true;
    googleIdTokenProvider = _FakeGoogle(unavailable: true);
    final deps = await buildDeps(tester);
    await openDeleteAccount(tester, deps);

    await tester.tap(find.text('Continue'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'secret123');
    await tester.tap(find.text('Deactivate account'));
    await settle(tester);

    expect(jsonDecode(deleteRequests.single.body), {'currentPassword': 'secret123'});
    expect(deps.authState.isAuthenticated, isFalse);
    ignoreLoginLayoutOverflow(tester);
  });
}
