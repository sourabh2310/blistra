/// JWT persistence for the legacy notifications HTTP stack.
///
/// New code must use [AuthStorage]/[AuthState] (secure storage on mobile).
/// This class is retained so the notifications feature keeps compiling while
/// it migrates to the shared session: when constructed with
/// [TokenStore.secured] it delegates to [AuthStorage]; the old
/// [TokenStore](SharedPreferences) constructor is deprecated and only kept
/// for existing tests/call sites.
///
/// The in-memory [_cached] token is the synchronous source of truth for
/// [token]/[isAuthenticated] (secure storage reads are async).
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_storage.dart';

class TokenStore {
  /// Legacy constructor (insecure on its own) — deprecated.
  /// Prefer [TokenStore.secured].
  TokenStore(this._prefs, {this.key = 'auth_token'}) : _storage = null;

  /// Secure-backed constructor used by the new app wiring.
  TokenStore.secured(AuthStorage storage, {this.key = 'auth_token'})
      : _storage = storage,
        _prefs = null;

  final SharedPreferences? _prefs;
  final AuthStorage? _storage;
  final String key;

  String? _cached;

  /// Synchronous cached token (null until [load] or [save]).
  String? get token => _cached ?? _prefs?.getString(key);

  bool get isAuthenticated {
    final value = token;
    return value != null && value.isNotEmpty;
  }

  /// Async read-through (used by tests and refresh flows).
  Future<String?> read() async {
    if (_cached != null) return _cached;
    if (_storage != null) {
      _cached = await _storage.readToken();
      return _cached;
    }
    return _prefs?.getString(key);
  }

  /// Prime the in-memory cache (e.g. from [AuthState] at startup).
  void prime(String? value) {
    _cached = value;
  }

  Future<void> load() async {
    _cached = await read();
  }

  Future<void> save(String value) async {
    _cached = value;
    if (_storage != null) {
      await _storage.saveSession(token: value, email: '');
      return;
    }
    await _prefs?.setString(key, value);
  }

  Future<void> clear() async {
    _cached = null;
    if (_storage != null) {
      await _storage.clear();
      return;
    }
    await _prefs?.remove(key);
  }
}
