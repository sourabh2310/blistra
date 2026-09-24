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
  int _bindGeneration = 0;

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
    final generation = ++_bindGeneration;
    _userKey = userKey;
    _loading = userKey != null && userKey.isNotEmpty;
    _saving = false;
    _error = null;
    _bottomNav = List.of(ShellDestinations.defaults);
    _homeWidgets = List.of(HomeWidgets.defaults);
    notifyListeners();
    if (userKey == null || userKey.isEmpty) return;
    await _loadCached(userKey, generation);
    if (!_isCurrent(userKey, generation)) return;
    await _refreshFor(userKey, generation);
  }

  Future<void> refresh() async {
    final userKey = _userKey;
    if (userKey == null || userKey.isEmpty) return;
    await _refreshFor(userKey, _bindGeneration);
  }

  Future<void> _refreshFor(String userKey, int generation) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final payload = await _api.getPreferences();
      if (!_isCurrent(userKey, generation)) return;
      final nav = ShellDestinations.normalizeNav(payload.bottomNav);
      final widgets = HomeWidgets.normalizeWidgets(payload.homeWidgets);
      _bottomNav = nav;
      _homeWidgets = widgets;
      await _saveCached(userKey, nav, widgets);
    } catch (e) {
      if (_isCurrent(userKey, generation) && _error == null) {
        _error = e.toString();
      }
    } finally {
      if (_isCurrent(userKey, generation)) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrent(String userKey, int generation) =>
      _userKey == userKey && _bindGeneration == generation;

  Future<bool> save({
    required List<String> bottomNav,
    required List<String> homeWidgets,
  }) async {
    final normalizedNav = ShellDestinations.normalizeNav(bottomNav);
    final normalizedWidgets = HomeWidgets.normalizeWidgets(homeWidgets);
    final userKey = _userKey;
    final generation = _bindGeneration;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final payload = await _api.updatePreferences(
        bottomNav: normalizedNav,
        homeWidgets: normalizedWidgets,
      );
      if (!_isCurrent(userKey ?? '', generation)) return false;
      final savedNav = ShellDestinations.normalizeNav(payload.bottomNav);
      final savedWidgets = HomeWidgets.normalizeWidgets(payload.homeWidgets);
      _bottomNav = savedNav;
      _homeWidgets = savedWidgets;
      if (userKey != null && userKey.isNotEmpty) {
        await _saveCached(userKey, savedNav, savedWidgets);
      }
      return true;
    } catch (e) {
      if (_isCurrent(userKey ?? '', generation)) _error = e.toString();
      return false;
    } finally {
      if (_isCurrent(userKey ?? '', generation)) {
        _saving = false;
        notifyListeners();
      }
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

  Future<void> _loadCached(String userKey, int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final nav = prefs.getStringList(_cacheKey(userKey, 'nav'));
      final widgets = prefs.getStringList(_cacheKey(userKey, 'widgets'));
      if (!_isCurrent(userKey, generation)) return;
      if (nav != null && nav.isNotEmpty) {
        _bottomNav = ShellDestinations.normalizeNav(nav);
      }
      if (widgets != null && widgets.isNotEmpty) {
        _homeWidgets = HomeWidgets.normalizeWidgets(widgets);
      }
      notifyListeners();
    } catch (_) {
      return;
    }
  }

  Future<void> _saveCached(
    String userKey,
    List<String> nav,
    List<String> widgets,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_cacheKey(userKey, 'nav'), nav);
      await prefs.setStringList(_cacheKey(userKey, 'widgets'), widgets);
    } catch (_) {
      return;
    }
  }
}
