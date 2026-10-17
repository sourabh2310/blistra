import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exception.dart';
import 'package:frontend/core/auth/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'an old account response cannot log out or return data to the new account',
    () async {
      for (final status in [200, 401]) {
        final response = Completer<http.Response>();
        var unauthorized = false;
        final client = ApiClient(
          baseUrl: 'http://localhost',
          httpClient: MockClient((_) => response.future),
          onUnauthorized: () async {
            unauthorized = true;
          },
        );
        client.token = 'account-a';
        final request = client.get('/private');
        final check = expectLater(
          request,
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              'SESSION_CHANGED',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        client.token = 'account-b';
        response.complete(http.Response('{"private":"account-a"}', status));
        await check;
        expect(unauthorized, isFalse);
        expect(client.token, 'account-b');
        client.close();
      }
    },
  );
  test('failed secure storage keeps only a memory session and clears legacy plaintext', () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'old-plaintext',
      'auth_email': 'old@example.com',
    });
    const channel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          channel,
          (_) async => throw PlatformException(code: 'unavailable'),
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final storage = AuthStorage();
    await storage.saveSession(token: 'new-secret', email: 'me@example.com');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_token'), isNull);
    expect(prefs.getString('auth_email'), isNull);
    expect(await storage.readToken(), 'new-secret');
    expect(await AuthStorage().readToken(), isNull);
    await storage.clear();
    expect(await storage.readToken(), isNull);
  });
}
