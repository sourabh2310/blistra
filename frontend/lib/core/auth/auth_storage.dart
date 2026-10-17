/// Secure persistence for authentication credentials.
///
/// Uses platform secure storage on native platforms. If it is unavailable,
/// or on web, the session lives in memory and requires login after restart.
/// Credentials are never written to plaintext preferences.
///
/// Never stores passwords — only the JWT and the user email (non-secret).
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage({this._secure, this._prefs});

  static const String tokenKey = 'auth_token';
  static const String emailKey = 'auth_email';
  static const String _restoreAllowedKey = 'auth_secure_session_enabled';

  final FlutterSecureStorage? _secure;
  SharedPreferences? _prefs;
  String? _memoryToken;
  String? _memoryEmail;

  FlutterSecureStorage get _secureStore =>
      _secure ?? const FlutterSecureStorage();

  /// Secure storage is available on mobile/desktop native platforms only.
  static bool get supportsSecureStorage => !kIsWeb;

  Future<SharedPreferences> _fallbackPrefs() async {
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    // Older fallback credentials are intentionally not restored.
    await prefs.remove(tokenKey);
    await prefs.remove(emailKey);
    return prefs;
  }

  Future<String?> readToken() async {
    if (_memoryToken != null) return _memoryToken;
    if ((await _fallbackPrefs()).getBool(_restoreAllowedKey) == false) {
      return null;
    }
    if (supportsSecureStorage) {
      try {
        return await _secureStore.read(key: tokenKey) ?? _memoryToken;
      } catch (_) {
        return _memoryToken;
      }
    }
    return _memoryToken;
  }

  Future<String?> readEmail() async {
    if (_memoryEmail != null) return _memoryEmail;
    if ((await _fallbackPrefs()).getBool(_restoreAllowedKey) == false) {
      return null;
    }
    if (supportsSecureStorage) {
      try {
        return await _secureStore.read(key: emailKey) ?? _memoryEmail;
      } catch (_) {
        return _memoryEmail;
      }
    }
    return _memoryEmail;
  }

  Future<void> saveSession({
    required String token,
    required String email,
  }) async {
    _memoryToken = token;
    _memoryEmail = email;
    // Remove credentials left by older builds that used plaintext fallback.
    final prefs = await _fallbackPrefs();
    await prefs.setBool(_restoreAllowedKey, false);
    await prefs.remove(tokenKey);
    await prefs.remove(emailKey);
    if (supportsSecureStorage) {
      try {
        await _secureStore.write(key: tokenKey, value: token);
        await _secureStore.write(key: emailKey, value: email);
        await prefs.setBool(_restoreAllowedKey, true);
        return;
      } catch (_) {
        // Keep the current session in memory when secure storage fails.
      }
    }
  }

  Future<void> clear() async {
    _memoryToken = null;
    _memoryEmail = null;
    final prefs = await _fallbackPrefs();
    await prefs.setBool(_restoreAllowedKey, false);
    if (supportsSecureStorage) {
      try {
        await _secureStore.delete(key: tokenKey);
        await _secureStore.delete(key: emailKey);
      } catch (_) {
        // Best effort.
      }
    }
    await prefs.remove(tokenKey);
    await prefs.remove(emailKey);
  }
}
