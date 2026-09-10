import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import 'auth_repository.dart';
import 'token_store.dart';

enum AuthStatus {
  /// No token has been restored or created yet (app boot).
  restoring,

  /// Not authenticated; the login/register screen is shown.
  unauthenticated,

  /// Session restored from storage or just created.
  authenticated,
}

/// Owns the session lifecycle: restoring, login, registration and logout.
class AuthController extends ChangeNotifier {
  AuthController({required this.repository, required this.tokenStore});

  final AuthRepository repository;
  final TokenStore tokenStore;

  AuthStatus _status = AuthStatus.restoring;
  String? _email;
  String? _error;
  bool _busy = false;

  AuthStatus get status => _status;

  String? get email => _email;

  String? get error => _error;

  bool get busy => _busy;

  /// Called at app boot to restore a persisted session.
  Future<void> restore() async {
    if (tokenStore.hasSession) {
      _email = tokenStore.email;
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    _error = null;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) async {
    return _run(() => repository.login(email: email, password: password));
  }

  Future<bool> register({required String email, required String password}) async {
    return _run(() => repository.register(email: email, password: password));
  }

  Future<bool> _run(Future<AuthResult> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final result = await action();
      if (result.token.isEmpty) {
        _error = 'The server did not return an authentication token.';
        return false;
      }
      await tokenStore.save(result.token, result.user.email);
      _email = result.user.email;
      _status = AuthStatus.authenticated;
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } on NetworkException {
      _error = 'Cannot reach the server. Check your connection and try again.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await tokenStore.clear();
    _email = null;
    _error = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Clears the session without notifying the UI, used when the backend
  /// reports 401 for an otherwise-confirmed session.
  Future<void> forceLogout() async {
    await tokenStore.clear();
    _email = null;
    _error = null;
    _status = AuthStatus.unauthenticated;
  }

  /// The current bearer token, or null when not authenticated.
  String? get token => tokenStore.token;
}