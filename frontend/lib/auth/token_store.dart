import 'package:shared_preferences/shared_preferences.dart';

/// Persists the authenticated session (bearer token and the cached email) so
/// the app can restore a session across launches.
class TokenStore {
  TokenStore(this._prefs);

  static const _tokenKey = 'auth_token';
  static const _emailKey = 'auth_email';

  final SharedPreferences _prefs;

  /// Loads the store. Reset before every test or when a fresh session is
  /// required.
  static Future<TokenStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return TokenStore(prefs);
  }

  /// Clears any cached preferences. Used by tests to start clean.
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
  }

  String? get token => _prefs.getString(_tokenKey);

  String? get email => _prefs.getString(_emailKey);

  bool get hasSession =>
      _prefs.getString(_tokenKey) != null &&
      _prefs.getString(_tokenKey)!.isNotEmpty;

  Future<void> save(String token, String email) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_emailKey, email);
  }

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_emailKey);
  }
}