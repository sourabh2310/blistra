/// Thin typed HTTP client for the Blistra backend.
///
/// The backend URL defaults to the Android emulator loopback and can be
/// overridden at build time with `--dart-define=API_BASE_URL=...` or by
/// constructing [ApiClient] directly (also how tests inject fakes).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  Future<UserResponseDto> register(String email, String password) async {
    final body = await _send(
      'POST',
      '/api/v1/auth/register',
      body: {'email': email, 'password': password},
      expectStatus: 201,
    ) as Map<String, dynamic>;
    return UserResponseDto.fromJson(body);
  }

  Future<AuthResponseDto> login(String email, String password) async {
    final body = await _send(
      'POST',
      '/api/v1/auth/login',
      body: {'email': email, 'password': password},
      expectStatus: 200,
    ) as Map<String, dynamic>;
    final AuthResponseDto response = AuthResponseDto.fromJson(body);
    token = response.token;
    return response;
  }

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
    return ApiException(statusCode, code, message, fieldErrors: fieldErrors);
  }

  void close() {
    _http.close();
  }
}