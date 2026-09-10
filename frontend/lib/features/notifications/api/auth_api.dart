import 'blistra_api_client.dart';

/// Client for the backend authentication endpoints (`/api/v1/auth`).
class AuthApi {
  AuthApi(this._client);

  final BlistraApiClient _client;

  static const String _registerPath = '/api/v1/auth/register';
  static const String _loginPath = '/api/v1/auth/login';

  /// Creates an account and returns a bearer token (register then login).
  Future<String> register({required String email, required String password}) async {
    await _client.post(_registerPath, body: {
      'email': email,
      'password': password,
    });
    return login(email: email, password: password);
  }

  /// Exchanges credentials for a bearer token.
  Future<String> login({required String email, required String password}) async {
    final json = await _client.post(_loginPath, body: {
      'email': email,
      'password': password,
    });
    return json['token'] as String;
  }
}