import '../core/api_client.dart';

class AuthUser {
  AuthUser({required this.id, required this.email, required this.status});

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  final String id;
  final String email;
  final String status;
}

class AuthResult {
  AuthResult({required this.token, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String? ?? '',
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>? ?? {}),
    );
  }

  final String token;
  final AuthUser user;
}

/// Talks to `/api/v1/auth` (register/login).
class AuthRepository {
  AuthRepository(ApiClient client) : _client = client;

  final ApiClient _client;

  Future<AuthResult> register({required String email, required String password}) async {
    final json = await _client.postJson('/api/v1/auth/register',
        body: {'email': email, 'password': password}, auth: AuthMode.none);
    return AuthResult.fromJson(_asMap(json));
  }

  Future<AuthResult> login({required String email, required String password}) async {
    final json = await _client.postJson('/api/v1/auth/login',
        body: {'email': email, 'password': password}, auth: AuthMode.none);
    return AuthResult.fromJson(_asMap(json));
  }

  static Map<String, dynamic> _asMap(dynamic json) {
    if (json is Map<String, dynamic>) {
      return json;
    }
    throw ArgumentError.value(json, 'json', 'Expected a JSON object');
  }
}