import 'package:blistra/core/api/api_config.dart';
import 'dart:convert';

/// Repository for authentication operations
class AuthRepository {
  final ApiConfig _api;

  AuthRepository(this._api);

  /// Register a new user
  Future<AuthResult> register(String email, String password) async {
    final response = await _api.post('/auth/register', body: {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return AuthResult.success(data['id'], data['email']);
    } else {
      final error = _parseError(response);
      return AuthResult.failure(error);
    }
  }

  /// Login and store token
  Future<AuthResult> login(String email, String password) async {
    final response = await _api.post('/auth/login', body: {
      'email': email,
      'password': password,
    });

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'] as String;
      await _api.setToken(token);
      return AuthResult.success(data['user']['id'], data['user']['email']);
    } else {
      final error = _parseError(response);
      return AuthResult.failure(error);
    }
  }

  /// Logout and clear token
  Future<void> logout() async {
    await _api.clearToken();
  }

  String _parseError(http.Response response) {
    try {
      final data = jsonDecode(response.body);
      return data['message'] ?? 'Request failed with status ${response.statusCode}';
    } catch (_) {
      return 'Request failed with status ${response.statusCode}';
    }
  }
}

/// Result of an auth operation
class AuthResult {
  final bool success;
  final String? userId;
  final String? email;
  final String? error;

  AuthResult._({required this.success, this.userId, this.email, this.error});

  factory AuthResult.success(String userId, String email) =>
      AuthResult._(success: true, userId: userId, email: email);

  factory AuthResult.failure(String error) =>
      AuthResult._(success: false, error: error);
}