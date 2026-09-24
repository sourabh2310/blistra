/// Secure persistence for authentication credentials.
///
/// Uses platform secure storage (Keychain/Keystore) on Android/iOS/macOS via
/// `flutter_secure_storage`. On web and desktop platforms where secure
/// enclave storage is unavailable, falls back to `SharedPreferences` with an
/// explicit documented trade-off: browser/desktop storage is NOT equivalent
/// to native secure storage.
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

  final FlutterSecureStorage? _secure;
  SharedPreferences? _prefs;

  FlutterSecureStorage get _secureStore =>
      _secure ?? const FlutterSecureStorage();

  /// Secure storage is available on mobile/desktop native platforms only.
  static bool get supportsSecureStorage => !kIsWeb;

  Future<SharedPreferences> _fallbackPrefs() async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<String?> readToken() async {
    if (supportsSecureStorage) {
      try {
        return await _secureStore.read(key: tokenKey);
      } catch (_) {
        // Fall through to insecure fallback only if secure store fails
        // (e.g. unit tests without platform channels).
        final prefs = await _fallbackPrefs();
        return prefs.getString(tokenKey);
      }
    }
    final prefs = await _fallbackPrefs();
    return prefs.getString(tokenKey);
  }

  Future<String?> readEmail() async {
    if (supportsSecureStorage) {
      try {
        return await _secureStore.read(key: emailKey);
      } catch (_) {
        final prefs = await _fallbackPrefs();
        return prefs.getString(emailKey);
      }
    }
    final prefs = await _fallbackPrefs();
    return prefs.getString(emailKey);
  }

  Future<void> saveSession({
    required String token,
    required String email,
  }) async {
    if (supportsSecureStorage) {
      try {
        await _secureStore.write(key: tokenKey, value: token);
        await _secureStore.write(key: emailKey, value: email);
        return;
      } catch (_) {
        // Fall through to prefs when platform channels are unavailable
        // (tests) — never crash login because of storage.
      }
    }
    final prefs = await _fallbackPrefs();
    await prefs.setString(tokenKey, token);
    await prefs.setString(emailKey, email);
  }

  Future<void> clear() async {
    if (supportsSecureStorage) {
      try {
        await _secureStore.delete(key: tokenKey);
        await _secureStore.delete(key: emailKey);
      } catch (_) {
        // Best effort.
      }
    }
    final prefs = await _fallbackPrefs();
    await prefs.remove(tokenKey);
    await prefs.remove(emailKey);
  }
}
