/// App-facing state for per-user Home/navigation customization.
///
/// Source of truth is the backend (`GET/PUT /api/v1/preferences`, owned by
/// the JWT identity). A per-user SharedPreferences cache covers offline/cold
/// start; client-side normalization mirrors the backend rules (the server
/// re-validates and rejects unknown identifiers).
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'preferences_api.dart';
import 'shell_destinations.dart';

class PreferencesController extends ChangeNotifier {
  PreferencesController(this._api);

  final PreferencesApi _api;

  List<String> _bottomNav = List.of(ShellDestinations.defaults);
  List<String> _homeWidgets = List.of(HomeWidgets.defaults);
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _userKey;

  List<String> get bottomNav => List.unmodifiable(_bottomNav);
  List<String> get homeWidgets => List.unmodifiable(_homeWidgets);
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  /// Visible Home widgets in order (hero always first).
  List<String> get visibleHomeWidgets => List.unmodifiable(_homeWidgets);

  /// Binds the controller to the signed-in user and loads their preferences:
  /// cached values first (no flash), then the backend source of truth.
  Future<void> bindUser(String? userKey) async {
    if (_userKey == userKey && _userKey != null) return;
    _userKey = userKey;
    if (userKey == null || userKey.isEmpty) {
      _bottomNav = List.of(ShellDestinations.defaults);
      _homeWidgets = List.of(HomeWidgets.defaults);
      notifyListeners();
      return;
    }
    await _loadCached(userKey);
    await refresh();
  }

  Future<void> refresh() async {
    if (_userKey == null || _userKey!.isEmpty) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final payload = await _api.getPreferences();
      _bottomNav = ShellDestinations.normalizeNav(payload.bottomNav);
      _homeWidgets = HomeWidgets.normalizeWidgets(payload.homeWidgets);
      await _saveCached(_userKey!);
    } catch (e) {
      // Offline/cold-start: keep cache/defaults; surface a quiet error only
      // when nothing usable is present.
      if (_error == null) _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save({
    required List<String> bottomNav,
    required List<String> homeWidgets,
  }) async {
    final nav = ShellDestinations.normalizeNav(bottomNav);
    final widgets = HomeWidgets.normalizeWidgets(homeWidgets);
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final payload = await _api.updatePreferences(
        bottomNav: nav,
        homeWidgets: widgets,
      );
      _bottomNav = ShellDestinations.normalizeNav(payload.bottomNav);
      _homeWidgets = HomeWidgets.normalizeWidgets(payload.homeWidgets);
      if (_userKey != null && _userKey!.isNotEmpty) {
        await _saveCached(_userKey!);
      }
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> resetToDefaults() {
    return save(
      bottomNav: ShellDestinations.defaults,
      homeWidgets: HomeWidgets.defaults,
    );
  }

  String _cacheKey(String userKey, String field) =>
      'prefs:$userKey:$field';

  Future<void> _loadCached(String userKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nav = prefs.getStringList(_cacheKey(userKey, 'nav'));
      final widgets = prefs.getStringList(_cacheKey(userKey, 'widgets'));
      if (nav != null && nav.isNotEmpty) {
        _bottomNav = ShellDestinations.normalizeNav(nav);
      }
      if (widgets != null && widgets.isNotEmpty) {
        _homeWidgets = HomeWidgets.normalizeWidgets(widgets);
      }
      notifyListeners();
    } catch (_) {
      // Cache is best-effort only.
    }
  }

  Future<void> _saveCached(String userKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_cacheKey(userKey, 'nav'), _bottomNav);
      await prefs.setStringList(_cacheKey(userKey, 'widgets'), _homeWidgets);
    } catch (_) {
      // Cache is best-effort only.
    }
  }
}
