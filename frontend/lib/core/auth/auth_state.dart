/// In-memory authentication session backed by the real backend API.
///
/// Flow: register/login → persist JWT via [AuthStorage] (secure storage on
/// mobile, documented fallback on web) → update state → shell opens.
/// Logout/401 → clear credentials → unauthenticated → login screen.
///
/// No fake credentials. No passwords stored. No tokens logged.
library;

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'auth_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, busy }

class AuthState extends ChangeNotifier {
  AuthState({required this.apiClient, AuthStorage? storage})
      : _storage = storage ?? AuthStorage();

  final ApiClient apiClient;
  final AuthStorage _storage;

  AuthStatus _status = AuthStatus.unknown;
  String _userEmail = '';
  ApiException? _lastError;

  AuthStatus get status => _status;
  String get userEmail => _userEmail;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  ApiException? get lastError => _lastError;

  /// Restores a persisted session at startup. Must be awaited before the
  /// first frame decides between shell and login.
  Future<void> restore() async {
    try {
      final token = await _storage.readToken();
      final email = await _storage.readEmail();
      if (token != null && token.isNotEmpty) {
        apiClient.token = token;
        _userEmail = email ?? '';
        _status = AuthStatus.authenticated;
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Called by [ApiClient.onUnauthorized] on HTTP 401.
  Future<void> handleUnauthorized() async {
    apiClient.token = null;
    await _storage.clear();
    _userEmail = '';
    _lastError = ApiException(401, 'UNAUTHORIZED', 'Session expired.');
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> register(String email, String password) async {
    _setBusy();
    try {
      await apiClient.register(email, password);
      await login(email, password);
    } on ApiException catch (error) {
      _fail(_safe(error));
    } catch (error) {
      _fail(NetworkException(error));
    }
  }

  Future<void> login(String email, String password) async {
    _setBusy();
    try {
      final AuthResponseDto response = await apiClient.login(email, password);
      _userEmail = response.userEmail.isNotEmpty ? response.userEmail : email;
      await _storage.saveSession(
        token: response.token,
        email: _userEmail,
      );
      _lastError = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } on ApiException catch (error) {
      _fail(_safe(error));
    } catch (error) {
      _fail(NetworkException(error));
    }
  }

  Future<void> logout() async {
    apiClient.token = null;
    try {
      await _storage.clear();
    } catch (_) {
      // Best effort: sign-out must never fail because of storage.
    }
    _userEmail = '';
    _lastError = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  void _setBusy() {
    _lastError = null;
    _status = AuthStatus.busy;
    notifyListeners();
  }

  void _fail(ApiException error) {
    _lastError = error;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Never surface internal/server details for 5xx.
  static ApiException _safe(ApiException error) {
    if (error.statusCode >= 500) {
      return ApiException(
        error.statusCode,
        error.code,
        'Something went wrong. Please try again.',
        fieldErrors: error.fieldErrors,
      );
    }
    return error;
  }
}
