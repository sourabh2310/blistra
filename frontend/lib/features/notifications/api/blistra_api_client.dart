import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api/api_exception.dart';
import 'token_store.dart';

/// Thin HTTP client for the Blistra backend.
///
/// - Attaches `Authorization: Bearer <token>` when a token is stored.
/// - Turns every non-2xx response into a typed [ApiException] using the
///   backend's `{status, code, message, errors}` error contract.
/// - Surfaces transport failures as [NetworkException].
class BlistraApiClient {
  BlistraApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    TokenStore? tokenStore,
  })  : _http = httpClient ?? http.Client(),
        _tokens = tokenStore;

  final String baseUrl;
  final http.Client _http;
  final TokenStore? _tokens;

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);

  Future<List<dynamic>> getList(String path) => _sendList('GET', path);

  Future<Map<String, dynamic>> post(String path,
          {Map<String, dynamic>? body}) =>
      _send('POST', path, body: body);

  Future<Map<String, dynamic>> put(String path,
          {Map<String, dynamic>? body}) =>
      _send('PUT', path, body: body);

  Future<void> delete(String path) => _send('DELETE', path);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _dispatch(method, path, body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <String, dynamic>{};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _toApiException(response);
  }

  Future<List<dynamic>> _sendList(String method, String path) async {
    final response = await _dispatch(method, path, null);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return <dynamic>[];
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw _toApiException(response);
  }

  Future<http.Response> _dispatch(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final token = _tokens?.token;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    try {
      final encodedBody = body == null ? null : jsonEncode(body);
      return switch (method) {
        'GET' => await _http.get(uri, headers: headers),
        'POST' => await _http.post(uri, headers: headers, body: encodedBody),
        'PUT' => await _http.put(uri, headers: headers, body: encodedBody),
        'DELETE' => await _http.delete(uri, headers: headers),
        _ => throw ArgumentError.value(method, 'method'),
      };
    } on http.ClientException catch (error) {
      throw NetworkException(error);
    } on TimeoutException catch (error) {
      throw NetworkException(error);
    }
  }

  ApiException _toApiException(http.Response response) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final code = (decoded['code'] as String?) ?? 'UNKNOWN_ERROR';
      final message = (decoded['message'] as String?) ?? 'Request failed';
      final fieldErrors = <String, String>{};
      if (decoded['errors'] is List) {
        for (final entry in decoded['errors'] as List) {
          final item = entry as Map<String, dynamic>;
          final field = (item['field'] as String?) ?? '';
          final fieldMessage = (item['message'] as String?) ?? '';
          if (field.isNotEmpty) fieldErrors[field] = fieldMessage;
        }
      }
      return ApiException(response.statusCode, code, message,
          fieldErrors: fieldErrors);
    } on FormatException {
      return ApiException(
          response.statusCode, 'UNKNOWN_ERROR', 'Request failed');
    }
  }
}