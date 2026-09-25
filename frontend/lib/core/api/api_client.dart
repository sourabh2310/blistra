/// Thin typed HTTP client for the Blistra backend.
///
/// The backend URL defaults to the Android emulator loopback and can be
/// overridden at build time with `--dart-define=API_BASE_URL=...` or by
/// constructing [ApiClient] directly (also how tests inject fakes).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'api_interceptor.dart';

class AuthResponseDto {
  AuthResponseDto({required this.token, required this.userEmail});

  final String token;
  final String userEmail;

  factory AuthResponseDto.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? user = json['user'] as Map<String, dynamic>?;
    return AuthResponseDto(
      token: json['token'] as String,
      userEmail: user?['email'] as String? ?? '',
    );
  }
}

class UserResponseDto {
  UserResponseDto({required this.id, required this.email});

  final String id;
  final String email;

  factory UserResponseDto.fromJson(Map<String, dynamic> json) => UserResponseDto(
        id: json['id'] as String,
        email: json['email'] as String,
      );
}

/// V1 account identity: username/email/phone + verification/onboarding flags.
/// Never carries a password or hash.
class UserAccountDto {
  UserAccountDto({
    required this.id,
    required this.username,
    required this.email,
    this.phone,
    required this.emailVerified,
    required this.phoneVerified,
    required this.onboardingCompleted,
    required this.status,
    this.token,
  });

  final String id;
  final String username;
  final String email;
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;
  final bool onboardingCompleted;
  final String status;
  final String? token;

  factory UserAccountDto.fromJson(Map<String, dynamic> json) => UserAccountDto(
        id: json['id'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        emailVerified: json['emailVerified'] as bool? ?? false,
        phoneVerified: json['phoneVerified'] as bool? ?? false,
        onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
        status: json['status'] as String? ?? '',
        token: json['token'] as String?,
      );

  bool get needsVerification =>
      !emailVerified || (phone != null && phone!.isNotEmpty && !phoneVerified);
}

/// OTP issuance metadata for resend UX (expiry + cooldown seconds).
class OtpIssuanceDto {
  OtpIssuanceDto({required this.expiresAt, required this.cooldownSeconds});

  final String expiresAt;
  final int cooldownSeconds;

  factory OtpIssuanceDto.fromJson(Map<String, dynamic> json) => OtpIssuanceDto(
        expiresAt: json['expiresAt'] as String? ?? '',
        cooldownSeconds: (json['resendCooldownSeconds'] as num?)?.toInt() ?? 60,
      );
}

/// Authenticated profile: identity + display/locale fields. Age is derived
/// server-side from dateOfBirth on every read, never stored.
class UserProfileDto {
  UserProfileDto({
    required this.userId,
    required this.username,
    required this.email,
    this.phone,
    required this.emailVerified,
    required this.phoneVerified,
    required this.onboardingCompleted,
    required this.status,
    this.displayName,
    this.dateOfBirth,
    this.age,
    this.country,
    this.timezone,
    this.language,
    this.unitSystem,
  });

  final String userId;
  final String username;
  final String email;
  final String? phone;
  final bool emailVerified;
  final bool phoneVerified;
  final bool onboardingCompleted;
  final String status;
  final String? displayName;
  final String? dateOfBirth;
  final int? age;
  final String? country;
  final String? timezone;
  final String? language;
  final String? unitSystem;

  factory UserProfileDto.fromJson(Map<String, dynamic> json) => UserProfileDto(
        userId: json['userId'] as String? ?? '',
        username: json['username'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String?,
        emailVerified: json['emailVerified'] as bool? ?? false,
        phoneVerified: json['phoneVerified'] as bool? ?? false,
        onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
        status: json['status'] as String? ?? '',
        displayName: json['displayName'] as String?,
        dateOfBirth: json['dateOfBirth'] as String?,
        age: (json['age'] as num?)?.toInt(),
        country: json['country'] as String?,
        timezone: json['timezone'] as String?,
        language: json['language'] as String?,
        unitSystem: json['unitSystem'] as String?,
      );

  bool get isOnboardingProfileComplete =>
      (displayName ?? '').trim().isNotEmpty &&
      dateOfBirth != null &&
      country != null &&
      timezone != null &&
      unitSystem != null;
}

/// Live availability result: null = not checked, true = free, false = taken.
class AvailabilityDto {
  AvailabilityDto({
    this.usernameAvailable,
    this.emailAvailable,
    this.phoneAvailable,
  });

  final bool? usernameAvailable;
  final bool? emailAvailable;
  final bool? phoneAvailable;

  factory AvailabilityDto.fromJson(Map<String, dynamic> json) =>
      AvailabilityDto(
        usernameAvailable: json['usernameAvailable'] as bool?,
        emailAvailable: json['emailAvailable'] as bool?,
        phoneAvailable: json['phoneAvailable'] as bool?,
      );
}

/// Verified recovery channels: only verified destinations, masked.
/// 404 means no account for the identifier — the UI must stop, no OTP.
class RecoveryChannelsDto {
  RecoveryChannelsDto({
    required this.channels,
    this.emailMasked,
    this.phoneMasked,
  });

  final List<String> channels;
  final String? emailMasked;
  final String? phoneMasked;

  bool get offersEmail => channels.contains('EMAIL');
  bool get offersSms =>
      channels.contains('SMS') || channels.contains('PHONE');

  factory RecoveryChannelsDto.fromJson(Map<String, dynamic> json) {
    final raw = json['channels'];
    return RecoveryChannelsDto(
      channels: [
        if (raw is List)
          for (final c in raw)
            if (c is String) c,
      ],
      emailMasked: json['emailMasked'] as String?,
      phoneMasked: json['phoneMasked'] as String?,
    );
  }
}

/// Development-only OTP retrieval payload.
class DevOtpDto {  DevOtpDto({
    required this.purpose,
    required this.channel,
    required this.code,
    required this.expiresAt,
  });

  final String purpose;
  final String channel;
  final String code;
  final String expiresAt;

  factory DevOtpDto.fromJson(Map<String, dynamic> json) => DevOtpDto(
        purpose: json['purpose'] as String? ?? '',
        channel: json['channel'] as String? ?? '',
        code: json['code'] as String? ?? '',
        expiresAt: json['expiresAt'] as String? ?? '',
      );
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 15),
    this.onUnauthorized,
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Per-request timeout applied to every network call.
  final Duration timeout;

  /// Invoked once when the backend answers 401 (expired/invalid JWT) so the
  /// session layer can clear credentials and return to login.
  Future<void> Function()? onUnauthorized;

  /// Bearer token attached to every request. Out of the box the app keeps it
  /// in memory only.
  String? token;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  Map<String, String> _headers() => buildHeaders(token: token);

  Future<Map<String, dynamic>> get(String path,
      {Map<String, String>? query}) async {
    final Object? decoded = await _send('GET', path, query: query);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(200, 'UNEXPECTED_RESPONSE', 'Expected a JSON object');
  }

  Future<List<dynamic>> getList(String path,
      {Map<String, String>? query}) async {
    final Object? decoded = await _send('GET', path, query: query);
    if (decoded is List) {
      return decoded;
    }
    throw ApiException(200, 'UNEXPECTED_RESPONSE', 'Expected a JSON array');
  }

  Future<Map<String, dynamic>> post(String path,
      {Map<String, dynamic>? body, int expectStatus = 201}) async {
    final Object? decoded = await _send('POST', path,
        body: body, expectStatus: expectStatus);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(expectStatus, 'UNEXPECTED_RESPONSE',
        'Expected a JSON object');
  }

  Future<Map<String, dynamic>> put(String path,
      {Map<String, dynamic>? body, int expectStatus = 200}) async {
    final Object? decoded = await _send('PUT', path,
        body: body, expectStatus: expectStatus);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(expectStatus, 'UNEXPECTED_RESPONSE',
        'Expected a JSON object');
  }

  Future<Map<String, dynamic>> patch(String path,
      {Map<String, dynamic>? body, int expectStatus = 200}) async {
    final Object? decoded = await _send('PATCH', path,
        body: body, expectStatus: expectStatus);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw ApiException(expectStatus, 'UNEXPECTED_RESPONSE',
        'Expected a JSON object');
  }

  Future<void> delete(String path) async {
    await _send('DELETE', path);
  }

  /// Raw-bytes GET for binary downloads (documents). Throws [ApiException]
  /// on non-2xx, mirroring the backend error contract.
  Future<Uint8List> getBytes(String path) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    final http.Request request = http.Request('GET', uri)
      ..headers.addAll(_headers());
    try {
      final http.StreamedResponse streamed =
          await _http.send(request).timeout(timeout);
      final http.Response response =
          await http.Response.fromStream(streamed).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw await _toApiExceptionAsync(response.statusCode,
            _tryDecode(response.body), response.body);
      }
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw NetworkException(error);
    } catch (error) {
      throw NetworkException(error);
    }
  }

  /// Multipart file upload. Returns the decoded JSON object on success.
  ///
  /// Upload progress is indeterminate with package:http, so [onProgress] is
  /// invoked once with 1.0 when the upload completes; callers should show an
  /// indeterminate indicator until then.
  Future<Map<String, dynamic>> uploadMultipart(
    String path, {
    required Map<String, String> fields,
    required List<http.MultipartFile> files,
    void Function(double progress)? onProgress,
    int expectStatus = 201,
  }) async {
    final Uri uri = Uri.parse('$baseUrl$path');
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headers())
      ..fields.addAll(fields)
      ..files.addAll(files);
    try {
      final http.StreamedResponse streamed =
          await _http.send(request).timeout(timeout);
      final http.Response response =
          await http.Response.fromStream(streamed).timeout(timeout);
      final Object? decoded = _tryDecode(response.body);
      if (response.statusCode != expectStatus) {
        throw await _toApiExceptionAsync(
            response.statusCode, decoded, response.body);
      }
      if (decoded is Map<String, dynamic>) {
        onProgress?.call(1.0);
        return decoded;
      }
      throw ApiException(expectStatus, 'UNEXPECTED_RESPONSE',
          'Expected a JSON object');
    } on ApiException {
      rethrow;
    } catch (error) {
      throw NetworkException(error);
    }
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    int? expectStatus,
  }) async {
    final Uri uri =
        Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final http.Request request = http.Request(method, uri)
      ..headers.addAll(_headers());
    if (body != null) {
      request.body = jsonEncode(body);
    }
    try {
      final http.StreamedResponse streamed =
          await _http.send(request).timeout(timeout);
      final http.Response response =
          await http.Response.fromStream(streamed).timeout(timeout);
      return _decode(response, expectStatus: expectStatus);
    } on ApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw NetworkException(error);
    } catch (error) {
      throw NetworkException(error);
    }
  }

  Object? _decode(http.Response response, {int? expectStatus}) {
    final Object? decoded = _tryDecode(response.body);
    // Empty-body success (e.g. HTTP 204 on DELETE) is valid.
    if (response.body.isEmpty &&
        (response.statusCode == 204 ||
            (expectStatus == null &&
                response.statusCode >= 200 &&
                response.statusCode < 300))) {
      return null;
    }
    if (response.statusCode == 401) {
      final cb = onUnauthorized;
      if (cb != null) {
        // Fire-and-forget: session cleanup must never break error mapping.
        // ignore: discarded_futures
        cb();
      }
    }
    if (expectStatus != null) {
      if (response.statusCode != expectStatus) {
        throw _toApiException(response.statusCode, decoded,
            rawBody: response.body);
      }
      return decoded;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _toApiException(response.statusCode, decoded,
          rawBody: response.body);
    }
    return decoded;
  }

  static Object? _tryDecode(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } on FormatException {
      return null;
    }
  }

  Future<ApiException> _toApiExceptionAsync(
    int statusCode,
    Object? decoded,
    String rawBody,
  ) async {
    if (statusCode == 401) {
      final cb = onUnauthorized;
      if (cb != null) {
        // ignore: discarded_futures
        cb();
      }
    }
    return _toApiException(statusCode, decoded, rawBody: rawBody);
  }

  static ApiException _toApiException(int statusCode, Object? decoded,
      {String rawBody = ''}) {
    final Map<String, dynamic>? json =
        decoded is Map<String, dynamic> ? decoded : null;
    if (json == null) {
      // Never surface raw HTML/stack traces; keep a safe message.
      final message = statusCode >= 500
          ? 'Something went wrong. Please try again.'
          : rawBody.isNotEmpty && rawBody.length < 200 && !rawBody.contains('<')
              ? rawBody
              : '';
      return ApiException(statusCode, 'HTTP_$statusCode', message);
    }
    final String code = json['code'] as String? ?? 'HTTP_$statusCode';
    var message = json['message'] as String? ?? '';
    if (statusCode >= 500 && (message.isEmpty || code == 'HTTP_$statusCode')) {
      message = 'Something went wrong. Please try again.';
    }
    final Map<String, String> fieldErrors = {};
    final Object? errors = json['errors'];
    if (errors is List) {
      for (final Object? element in errors) {
        if (element is Map<String, dynamic>) {
          final String? field = element['field'] as String?;
          final String? errorMessage = element['message'] as String?;
          if (field != null && errorMessage != null) {
            fieldErrors[field] = errorMessage;
          }
        }
      }
    }
    final int? retryAfter = json['retryAfterSeconds'] is num
        ? (json['retryAfterSeconds'] as num).toInt()
        : null;
    return ApiException(statusCode, code, message,
        fieldErrors: fieldErrors, retryAfterSeconds: retryAfter);
  }

  // ── Identity (V1): register / login / OTP / recovery / profile ──────

  /// Live availability check for the registration wizard. Only supplied
  /// fields are checked; each result is null when not checked, true when
  /// well-formed and free, false when taken or malformed.
  Future<AvailabilityDto> checkAvailability({
    String? username,
    String? email,
    String? phone,
  }) async {
    final body = await get('/api/v1/auth/availability', query: {
      if (username != null && username.isNotEmpty) 'username': username,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return AvailabilityDto.fromJson(body);
  }

  Future<UserAccountDto> register({
    String? username,
    required String email,
    String? phone,
    required String password,
    String? displayName,
    bool termsAccepted = true,
  }) async {
    final body = await _send(
      'POST',
      '/api/v1/auth/register',
      body: {
        'username':? username,
        'email': email,
        'phone':? phone,
        'password': password,
        'displayName':? displayName,
        'termsAccepted': termsAccepted,
      },
      expectStatus: 201,
    ) as Map<String, dynamic>;
    final account = UserAccountDto.fromJson(body);
    if ((account.token ?? '').isNotEmpty) {
      token = account.token;
    }
    return account;
  }

  Future<AuthResponseDto> login({
    required String identifier,
    required String password,
  }) async {
    final body = await _send(
      'POST',
      '/api/v1/auth/login',
      body: {'identifier': identifier, 'password': password},
      expectStatus: 200,
    ) as Map<String, dynamic>;
    final AuthResponseDto response = AuthResponseDto.fromJson(body);
    token = response.token;
    return response;
  }

  Future<UserAccountDto> verifyEmail(String code) async {
    final body = await post('/api/v1/auth/verify/email',
        body: {'code': code}, expectStatus: 200);
    return UserAccountDto.fromJson(body);
  }

  Future<UserAccountDto> verifyPhone(String code) async {
    final body = await post('/api/v1/auth/verify/phone',
        body: {'code': code}, expectStatus: 200);
    return UserAccountDto.fromJson(body);
  }

  Future<OtpIssuanceDto> resendEmailOtp() async {
    final body = await post('/api/v1/auth/resend/email', expectStatus: 200);
    return OtpIssuanceDto.fromJson(body);
  }

  Future<OtpIssuanceDto> resendPhoneOtp() async {
    final body = await post('/api/v1/auth/resend/phone', expectStatus: 200);
    return OtpIssuanceDto.fromJson(body);
  }
  Future<String> forgotPassword({required String identifier, String? channel}) async {
    final body = await _send(
      'POST',
      '/api/v1/auth/forgot-password',
      body: {
        'identifier': identifier,
        'channel':? channel,
      },
      expectStatus: 200,
    ) as Map<String, dynamic>;
    return body['message'] as String? ?? '';
  }

  /// Resolves verified recovery channels. Throws 404 (ACCOUNT_NOT_FOUND via
  /// RESOURCE_NOT_FOUND) for unknown identifiers — callers must stop there.
  Future<RecoveryChannelsDto> recoveryChannels({
    required String identifier,
  }) async {
    final body = await _send(
      'POST',
      '/api/v1/auth/recovery/channels',
      body: {'identifier': identifier},
      expectStatus: 200,
    ) as Map<String, dynamic>;
    return RecoveryChannelsDto.fromJson(body);
  }

  Future<String> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final body = await _send(
      'POST',
      '/api/v1/auth/reset-password',
      body: {
        'identifier': identifier,
        'code': code,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
      expectStatus: 200,
    ) as Map<String, dynamic>;
    return body['message'] as String? ?? '';
  }

  Future<UserAccountDto> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final body = await post('/api/v1/auth/change-password',
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
        expectStatus: 200);
    return UserAccountDto.fromJson(body);
  }

  Future<UserProfileDto> fetchProfile() async {
    final body = await get('/api/v1/profile');
    return UserProfileDto.fromJson(body);
  }

  Future<UserProfileDto> updateProfile(Map<String, Object?> fields) async {
    final body = await put('/api/v1/profile',
        body: Map<String, dynamic>.from(fields), expectStatus: 200);
    return UserProfileDto.fromJson(body);
  }

  Future<UserProfileDto> completeOnboarding() async {
    final body = await post('/api/v1/profile/complete-onboarding',
        expectStatus: 200);
    return UserProfileDto.fromJson(body);
  }

  Future<UserProfileDto> updateIdentity({
    required String currentPassword,
    String? username,
    String? email,
    String? phone,
  }) async {
    final body = await post('/api/v1/profile/identity',
        body: {
          'currentPassword': currentPassword,
          'username':? username,
          'email':? email,
          'phone':? phone,
        },
        expectStatus: 200);
    return UserProfileDto.fromJson(body);
  }

  Future<UserProfileDto> confirmIdentity({
    required String code,
    String channel = 'EMAIL',
  }) async {
    final body = await _send(
      'POST',
      '/api/v1/profile/identity/confirm?channel=$channel',
      body: {'code': code},
      expectStatus: 200,
    ) as Map<String, dynamic>;
    return UserProfileDto.fromJson(body);
  }

  /// Development-only: latest usable OTP for the account. The backend 404s
  /// outside dev OTP mode; the Flutter OTP screen uses the same verify API
  /// in both modes.
  Future<DevOtpDto> devOtp(String purpose) async {
    final body = await get('/api/v1/auth/dev/otp', query: {'purpose': purpose});
    return DevOtpDto.fromJson(body);
  }

  void close() {
    _http.close();
  }
}