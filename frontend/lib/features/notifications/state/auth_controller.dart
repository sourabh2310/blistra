import 'package:flutter/foundation.dart';
import 'package:frontend/features/notifications/api/auth_api.dart';
import 'package:frontend/features/notifications/api/token_store.dart';
import 'package:frontend/features/notifications/services/reminder_sync_service.dart';

import '../../../core/api/api_exception.dart';

/// Holds the authentication session state for the UI.
///
/// Authenticating always refreshes local notifications so the reminder
/// schedule is populated right after login. Logging out cancels reminder
/// notifications first (while the token is still valid), then clears the
/// stored token.
class AuthController extends ChangeNotifier {
  AuthController({
    required this._authApi,
    required this._tokens,
    required this._syncService,
  });

  final AuthApi _authApi;
  final TokenStore _tokens;
  final ReminderSyncService _syncService;

  bool _busy = false;
  String? _error;

  bool get isAuthenticated => _tokens.isAuthenticated;
  bool get busy => _busy;
  String? get error => _error;

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    await _authenticate(() => _authApi.login(email: email, password: password));
    return isAuthenticated;
  }

  Future<bool> register({
    required String email,
    required String password,
  }) async {
    await _authenticate(
        () => _authApi.register(email: email, password: password));
    return isAuthenticated;
  }

  Future<void> _authenticate(Future<String> Function() action) async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final token = await action();
      await _tokens.save(token);
      await _syncService.refresh();
    } on ApiException catch (error) {
      _error = error.message;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _syncService.clearAll();
    } catch (_) {
      // Best effort: local notifications must never block sign-out.
    }
    await _tokens.clear();
    notifyListeners();
  }
}