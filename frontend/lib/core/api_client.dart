import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'config.dart';
import 'errors.dart';

/// How the current request authenticates against the backend.
enum AuthMode {
  /// No Authorization header is sent (login/register).
  none,

  /// The stored bearer token is attached as `Authorization: Bearer <token>`.
  bearer,
}

/// Thin JSON client over [http.Client] that attaches the bearer token,
/// normalizes transport failures into [NetworkException], and turns non-2xx
/// responses into [ApiException] using the backend `ApiErrorResponse` shape.
///
/// [httpClient] is injectable so tests can drive the client with a fake
/// transport without touching the network.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    String? Function()? tokenProvider,
  })  : _http = httpClient ?? http.Client(),
        _tokenProvider = tokenProvider;

  final String baseUrl;
  final http.Client _http;
  final String? Function()? _tokenProvider;

  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    AuthMode auth = AuthMode.bearer,
  }) {
    return _send('GET', path, query: query, auth: auth);
  }

  Future<dynamic> postJson(
    String path, {
    Object? body,
    Map<String, String>? query,
    AuthMode auth = AuthMode.bearer,
  }) {
    return _send('POST', path, body: body, query: query, auth: auth);
  }

  Future<dynamic> putJson(
    String path, {
    Object? body,
    Map<String, String>? query,
    AuthMode auth = AuthMode.bearer,
  }) {
    return _send('PUT', path, body: body, query: query, auth: auth);
  }

  Future<void> deleteJson(
    String path, {
    Map<String, String>? query,
    AuthMode auth = AuthMode.bearer,
  }) async {
    await _send('DELETE', path, query: query, auth: auth);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    AuthMode auth = AuthMode.bearer,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
    };
    if (auth == AuthMode.bearer) {
      final token = _tokenProvider?.call();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    http.Response response;
    try {
      response = switch (method) {
        'GET' => await _http.get(uri, headers: headers),
        'POST' => await _http.post(uri, headers: headers, body: _encode(body)),
        'PUT' => await _http.put(uri, headers: headers, body: _encode(body)),
        'DELETE' => await _http.delete(uri, headers: headers),
        _ => throw ArgumentError.value(method, 'method', 'Unsupported method'),
      };
    } on SocketException {
      throw NetworkException();
    } on http.ClientException {
      throw NetworkException();
    } on TimeoutException {
      throw NetworkException(TimeoutException('Request timed out'));
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      try {
        return jsonDecode(response.body);
      } on FormatException catch (e) {
        throw ApiParseException('Invalid JSON response', e);
      }
    }

    throw _toApiException(response);
  }

  static String? _encode(Object? body) {
    if (body == null) {
      return null;
    }
    return jsonEncode(body);
  }

  static ApiException _toApiException(http.Response response) {
    Object? decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    String code = 'UNKNOWN';
    String message = 'Request failed';
    final fieldErrors = <String, String>{};
    if (decoded is Map<String, dynamic>) {
      final body = decoded;
      code = (body['code'] as String?) ?? code;
      message = (body['message'] as String?) ?? message;
      final errors = body['errors'];
      if (errors is List) {
        for (final entry in errors) {
          if (entry is Map<String, dynamic>) {
            final field = entry['field'] as String?;
            final errorMessage = entry['message'] as String?;
            if (field != null && errorMessage != null) {
              fieldErrors[field] = errorMessage;
            }
          }
        }
      }
    }

    return ApiException(
      status: response.statusCode,
      code: code,
      message: message,
      fieldErrors: fieldErrors,
    );
  }
}