import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exception.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/core/auth/auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiClient', () {
    test('attaches bearer token', () async {
      String? auth;
      final mock = MockClient((req) async {
        auth = req.headers['Authorization'];
        return http.Response('{"ok":true}', 200);
      });
      final api = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mock)
        ..token = 'jwt-123';
      await api.get('/api/v1/dashboard');
      expect(auth, 'Bearer jwt-123');
      api.close();
    });

    test('maps validation errors', () async {
      final mock = MockClient((_) async => http.Response(
          '{"status":400,"code":"VALIDATION_ERROR","message":"Bad",'
          '"errors":[{"field":"email","message":"Taken"}]}',
          400));
      final api = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mock);
      try {
        await api.post('/api/v1/auth/register',
            body: {'email': 'a', 'password': 'b'});
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.fieldErrors['email'], 'Taken');
      }
      api.close();
    });

    test('401 triggers onUnauthorized', () async {
      var called = 0;
      final mock = MockClient((_) async =>
          http.Response('{"code":"UNAUTHORIZED","message":"Expired"}', 401));
      final api = ApiClient(
        baseUrl: 'http://localhost:8080',
        httpClient: mock,
        onUnauthorized: () async => called++,
      );
      try {
        await api.get('/api/v1/dashboard');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.isUnauthorized, isTrue);
      }
      expect(called, 1);
      api.close();
    });

    test('500 surfaces safe message', () async {
      final mock = MockClient(
          (_) async => http.Response('Internal Server Error', 500));
      final api = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mock);
      try {
        await api.get('/api/v1/dashboard');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.message, isNotEmpty);
        expect(e.message, isNot(contains('Exception')));
      }
      api.close();
    });
  });

  group('AuthState', () {
    MockClient loginMock() => MockClient((req) async {
          if (req.url.path.endsWith('/auth/login')) {
            return http.Response(
                '{"token":"tok-1","user":{"email":"u@x.com"}}', 200);
          }
          if (req.url.path.endsWith('/auth/register')) {
            return http.Response(
                '{"id":"1","email":"u@x.com"}', 201);
          }
          return http.Response('{}', 200);
        });

    test('login persists session, logout clears', () async {
      final api = ApiClient(
          baseUrl: 'http://localhost:8080', httpClient: loginMock());
      final auth = AuthState(apiClient: api, storage: AuthStorage());
      await auth.login(identifier: 'u@x.com', password: 'password123');
      expect(auth.isAuthenticated, isTrue);
      expect(api.token, 'tok-1');

      await auth.logout();
      expect(auth.isAuthenticated, isFalse);
      expect(api.token, isNull);
      api.close();
    });

    test('restore picks up persisted session', () async {
      final api = ApiClient(
          baseUrl: 'http://localhost:8080', httpClient: loginMock());
      final storage = AuthStorage();
      final first = AuthState(apiClient: api, storage: storage);
      await first.login(identifier: 'u@x.com', password: 'password123');

      final api2 = ApiClient(
          baseUrl: 'http://localhost:8080', httpClient: loginMock());
      final second = AuthState(apiClient: api2, storage: storage);
      await second.restore();
      expect(second.isAuthenticated, isTrue);
      expect(api2.token, 'tok-1');
      api.close();
      api2.close();
    });

    test('handleUnauthorized clears session', () async {
      final api = ApiClient(
          baseUrl: 'http://localhost:8080', httpClient: loginMock())
        ..token = 'stale';
      final auth = AuthState(apiClient: api, storage: AuthStorage());
      await auth.handleUnauthorized();
      expect(auth.isAuthenticated, isFalse);
      expect(api.token, isNull);
      api.close();
    });
  });
}
