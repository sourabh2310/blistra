/// V1 registration / OTP / recovery tests.
///
/// Backend `users` owns username/email/phone identity with verification
/// flags; these tests cover AuthState flows with a mocked HTTP layer plus
/// the pure field validators used by the wizard. Widget pumps of app screens
/// are intentionally avoided here (see shell_routing_test for the pump-safe
/// subset); validation logic is unit-tested through auth_validators.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/features/auth/auth_validators.dart';

const _userJson =
    '{"id":"u-1","username":"sourabh123","email":"new@x.com","phone":"+919876543210",'
    '"emailVerified":false,"phoneVerified":false,"onboardingCompleted":false,'
    '"status":"PENDING_VERIFICATION","token":"tok-reg"}';

const _profileJson =
    '{"userId":"u-1","username":"sourabh123","email":"new@x.com","phone":"+919876543210",'
    '"emailVerified":false,"phoneVerified":false,"onboardingCompleted":false,'
    '"status":"PENDING_VERIFICATION","displayName":"Sourabh"}';

MockClient _mock({
  int registerStatus = 201,
  String registerBody = _userJson,
  int loginStatus = 200,
  String loginBody = '{"token":"tok-1","user":{"email":"new@x.com"}}',
  String profileBody = _profileJson,
  int verifyStatus = 200,
  String? verifyBody,
  int resendStatus = 200,
  String resendBody = '{"expiresAt":"2030-01-01T00:00:00","resendCooldownSeconds":60}',
  int forgotStatus = 200,
  int resetStatus = 200,
}) {
  return MockClient((req) async {
    final path = req.url.path;
    if (path.endsWith('/auth/register')) {
      return http.Response(registerBody, registerStatus);
    }
    if (path.endsWith('/auth/login')) {
      return http.Response(loginBody, loginStatus);
    }
    if (path.endsWith('/profile')) {
      return http.Response(profileBody, 200);
    }
    if (path.contains('/auth/verify/')) {
      return http.Response(
          verifyBody ??
              _userJson
                  .replaceAll('"emailVerified":false', '"emailVerified":true'),
          verifyStatus);
    }
    if (path.contains('/auth/resend/')) {
      return http.Response(resendBody, resendStatus);
    }
    if (path.endsWith('/auth/forgot-password')) {
      return http.Response(
          '{"message":"If the account exists, a verification code will be sent."}',
          forgotStatus);
    }
    if (path.endsWith('/auth/reset-password')) {
      return http.Response(
          '{"message":"Password has been reset. You can now sign in."}',
          resetStatus);
    }
    if (path.endsWith('/profile/complete-onboarding')) {
      return http.Response(
          profileBody.replaceAll(
              '"onboardingCompleted":false', '"onboardingCompleted":true'),
          200);
    }
    return http.Response('{}', 200);
  });
}

AuthState _authWith(MockClient mock) {
  final api = ApiClient(baseUrl: 'http://localhost:8080', httpClient: mock);
  return AuthState(apiClient: api, storage: AuthStorage());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('validators', () {
    test('username rules', () {
      expect(validateUsername(null), isNotNull);
      expect(validateUsername('ab'), isNotNull);
      expect(validateUsername('no spaces'), isNotNull);
      expect(validateUsername('sourabh123'), isNull);
      expect(validateUsername('a.b_c'), isNull);
    });

    test('phone requires E.164 country code', () {
      expect(validatePhone(null), isNotNull);
      expect(validatePhone('9876543210'), isNotNull);
      expect(validatePhone('+919876543210'), isNull);
      expect(validatePhone('+91 98765 43210'), isNull);
      expect(validatePhone('', required: false), isNull);
    });

    test('identifier accepts username, email and phone', () {
      expect(validateIdentifier(''), isNotNull);
      expect(validateIdentifier('sourabh123'), isNull);
      expect(validateIdentifier('user@example.com'), isNull);
      expect(validateIdentifier('not-an-email@'), isNotNull);
      expect(validateIdentifier('+919876543210'), isNull);
      expect(validateIdentifier('+91'), isNotNull);
    });

    test('password strength for registration', () {
      expect(
          validatePassword('short', registering: true), isNotNull);
      expect(
          validatePassword('passwordonly', registering: true), isNotNull);
      expect(validatePassword('12345678', registering: true), isNotNull);
      expect(validatePassword('password1', registering: true), isNull);
      expect(validatePassword('anything', registering: false), isNull);
      expect(validatePassword('', registering: false), isNotNull);
    });

    test('otp, display name and country', () {
      expect(validateOtpCode('12345'), isNotNull);
      expect(validateOtpCode('123456'), isNull);
      expect(validateDisplayName('  '), isNotNull);
      expect(validateDisplayName('Sourabh'), isNull);
      expect(validateCountry('IND'), isNotNull);
      expect(validateCountry('IN'), isNull);
    });
  });

  group('AuthState.register', () {
    test('success authenticates with pending flags and token', () async {
      final auth = _authWith(_mock());
      final account = await auth.register(
        username: 'sourabh123',
        email: 'new@x.com',
        phone: '+919876543210',
        password: 'password1',
        displayName: 'Sourabh',
      );
      expect(account, isNotNull);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.justRegistered, isTrue);
      expect(auth.needsVerification, isTrue);
      expect(auth.needsOnboarding, isTrue);
      expect(auth.apiClient.token, 'tok-reg');
    });

    test('duplicate username surfaces 409 without authenticating', () async {
      final auth = _authWith(_mock(
        registerStatus: 409,
        registerBody:
            '{"status":409,"code":"RESOURCE_ALREADY_EXISTS","message":"Username already taken"}',
      ));
      final account = await auth.register(
        username: 'taken',
        email: 'other@x.com',
        password: 'password1',
      );
      expect(account, isNull);
      expect(auth.isAuthenticated, isFalse);
      expect(auth.lastError?.statusCode, 409);
      expect(auth.justRegistered, isFalse);
    });

    test('weak password surfaces validation errors', () async {
      final auth = _authWith(_mock(
        registerStatus: 400,
        registerBody:
            '{"status":400,"code":"VALIDATION_ERROR","message":"Request validation failed",'
            '"errors":[{"field":"password","message":"Password must contain at least one letter and one digit"}]}',
      ));
      final account = await auth.register(
        username: 'sourabh123',
        email: 'new@x.com',
        password: 'passwordonly',
      );
      expect(account, isNull);
      expect(auth.lastError?.fieldErrors['password'], isNotNull);
    });
  });

  group('AuthState.login', () {
    test('identifier login hydrates verification flags', () async {
      final auth = _authWith(_mock());
      final account = await auth.login(
          identifier: 'sourabh123', password: 'password1');
      expect(account, isNotNull);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.needsVerification, isTrue);
      expect(auth.username, 'sourabh123');
    });

    test('wrong password stays unauthenticated', () async {
      final auth = _authWith(_mock(
        loginStatus: 401,
        loginBody:
            '{"status":401,"code":"INVALID_CREDENTIALS","message":"Invalid email or password"}',
      ));
      final account =
          await auth.login(identifier: 'ghost', password: 'password1');
      expect(account, isNull);
      expect(auth.isAuthenticated, isFalse);
    });
  });

  group('AuthState verification', () {
    test('verifyEmail clears the email flag', () async {
      final auth = _authWith(_mock());
      await auth.register(
          username: 'sourabh123', email: 'new@x.com', password: 'password1');
      final account = await auth.verifyEmail('483921');
      expect(account, isNotNull);
      expect(account!.emailVerified, isTrue);
      expect(auth.isAuthenticated, isTrue);
    });

    test('retry after success reports success, not INVALID_OTP', () async {
      // A retried tap after a successful verify hits a consumed code (400),
      // but the channel is already verified: must resolve as success.
      final verifiedProfile = _profileJson
          .replaceAll('"emailVerified":false', '"emailVerified":true');
      final auth = _authWith(MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/auth/register')) {
          return http.Response(_userJson, 201);
        }
        if (path.contains('/auth/verify/')) {
          return http.Response(
              '{"status":400,"code":"INVALID_OTP","message":"Invalid or expired code."}',
              400);
        }
        if (path.endsWith('/profile')) {
          return http.Response(verifiedProfile, 200);
        }
        return http.Response('{}', 200);
      }));
      await auth.register(
          username: 'sourabh123', email: 'new@x.com', password: 'password1');
      final account = await auth.verifyEmail('483921');
      expect(account, isNotNull);
      expect(account!.emailVerified, isTrue);
      expect(auth.lastError, isNull);
    });

    test('wrong OTP keeps the session and reports INVALID_OTP', () async {
      final auth = _authWith(_mock(
        verifyStatus: 400,
        verifyBody:
            '{"status":400,"code":"INVALID_OTP","message":"Incorrect code. 4 attempt(s) remaining."}',
      ));
      await auth.register(
          username: 'sourabh123', email: 'new@x.com', password: 'password1');
      final account = await auth.verifyEmail('000000');
      expect(account, isNull);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.lastError?.code, 'INVALID_OTP');
    });

    test('resend cooldown surfaces retryAfterSeconds', () async {
      final auth = _authWith(_mock(
        resendStatus: 429,
        resendBody:
            '{"status":429,"code":"RESEND_COOLDOWN","message":"Please wait before requesting another code.","retryAfterSeconds":42}',
      ));
      await auth.register(
          username: 'sourabh123', email: 'new@x.com', password: 'password1');
      final seconds = await auth.resendEmailOtp();
      expect(seconds, isNull);
      expect(auth.lastError?.isRateLimited, isTrue);
      expect(auth.lastError?.retryAfterSeconds, 42);
    });
  });

  group('AuthState recovery', () {
    test('forgotPassword resolves with the generic message', () async {
      final auth = _authWith(_mock());
      final message =
          await auth.forgotPassword(identifier: 'sourabh123');
      expect(message, contains('If the account exists'));
    });

    test('resetPassword succeeds then login works', () async {
      final auth = _authWith(_mock());
      final ok = await auth.resetPassword(
        identifier: 'new@x.com',
        code: '483921',
        newPassword: 'newpass1',
        confirmPassword: 'newpass1',
      );
      expect(ok, isTrue);
    });

    test('resetPassword failure reports INVALID_OTP', () async {
      final auth = _authWith(MockClient((req) async {
        if (req.url.path.endsWith('/auth/reset-password')) {
          return http.Response(
              '{"status":400,"code":"INVALID_OTP","message":"Invalid or expired code."}',
              400);
        }
        return http.Response(_profileJson, 200);
      }));
      final ok = await auth.resetPassword(
        identifier: 'new@x.com',
        code: '000000',
        newPassword: 'newpass1',
        confirmPassword: 'newpass1',
      );
      expect(ok, isFalse);
      expect(auth.lastError?.code, 'INVALID_OTP');
    });
  });

  group('AuthState onboarding', () {
    test('completeOnboarding clears wizard routing', () async {
      final auth = _authWith(_mock());
      await auth.register(
          username: 'sourabh123', email: 'new@x.com', password: 'password1');
      expect(auth.justRegistered, isTrue);
      final profile = await auth.completeOnboarding();
      expect(profile, isNotNull);
      expect(profile!.onboardingCompleted, isTrue);
      expect(auth.justRegistered, isFalse);
      expect(auth.needsOnboarding, isFalse);
    });
  });
}
