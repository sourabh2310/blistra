import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized API configuration and HTTP client wrapper.
class ApiConfig {
  static const String _defaultBaseUrl = 'http://10.0.2.2:8080/api/v1';
  static const String _tokenKey = 'auth_token';

  final String baseUrl;
  final http.Client _client;
  String? _token;

  ApiConfig({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = client ?? http.Client();

  /// Current auth token (null if not logged in)
  String? get token => _token;

  /// Whether user is currently authenticated
  bool get isAuthenticated => _token != null;

  /// Initialize from stored preferences
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenKey);
  }

  /// Set auth token and persist
  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey);
    }
  }

  /// Clear auth token
  Future<void> clearToken() async {
    await setToken(null);
  }

  /// Common headers including auth
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  /// GET request
  Future<http.Response> get(String path,
      {Map<String, String>? headers, Map<String, dynamic>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    return _client.get(uri, headers: {..._headers, ...?headers});
  }

  /// POST request with JSON body
  Future<http.Response> post(String path,
      {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    return _client.post(
      uri,
      headers: {..._headers, ...?headers},
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// PATCH request with JSON body
  Future<http.Response> patch(String path,
      {Map<String, String>? headers, Object? body}) async {
    final uri = Uri.parse('$baseUrl$path');
    return _client.patch(
      uri,
      headers: {..._headers, ...?headers},
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// DELETE request
  Future<http.Response> delete(String path,
      {Map<String, String>? headers}) async {
    final uri = Uri.parse('$baseUrl$path');
    return _client.delete(uri, headers: {..._headers, ...?headers});
  }

  /// Multipart POST for file upload with progress
  Future<http.StreamedResponse> uploadMultipart(
    String path, {
    required Map<String, String> fields,
    required List<MultipartFile> files,
    Map<String, String>? headers,
    void Function(int sent, int total)? onProgress,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final request = http.MultipartRequest('POST', uri)
      ..fields.addAll(fields)
      ..files.addAll(files)
      ..headers.addAll({..._headers, ...?headers});

    final streamed = await _client.send(request);

    if (onProgress != null && streamed.contentLength != null) {
      int sent = 0;
      await streamed.stream.listen((chunk) {
        sent += chunk.length;
        onProgress(sent, streamed.contentLength!);
      }).asFuture();
    }

    return streamed;
  }

  void dispose() {
    _client.close();
  }
}

/// Simple multipart file wrapper for upload
class MultipartFile {
  final String fieldName;
  final String fileName;
  final String contentType;
  final List<int> bytes;

  const MultipartFile({
    required this.fieldName,
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  http.MultipartFile toHttpMultipartFile() {
    return http.MultipartFile.fromBytes(fieldName, bytes,
        filename: fileName, contentType: MediaType.parse(contentType));
  }
}