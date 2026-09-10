import 'package:shared_preferences/shared_preferences.dart';

/// Persists the JWT access token across app restarts.
///
/// The backend is the source of truth for sessions; this store exists only so
/// the app can attach `Authorization: Bearer <token>` to every request.
class TokenStore {
  TokenStore(this._prefs, {this.key = 'auth_token'});

  final SharedPreferences _prefs;
  final String key;

  String? get token => _prefs.getString(key);

  bool get isAuthenticated {
    final value = token;
    return value != null && value.isNotEmpty;
  }

  Future<void> save(String value) async {
    await _prefs.setString(key, value);
  }

  Future<void> clear() async {
    await _prefs.remove(key);
  }
}