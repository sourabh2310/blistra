/// Pre-login-safe theme preference: System / Light / Dark.
///
/// Stored in SharedPreferences (no account required) so the choice survives
/// restarts before login. After login the same controller backs
/// Profile → Preferences → Appearance; a pre-login choice is preserved
/// unless the user changes it.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accent_palette.dart';

class ThemeController extends ChangeNotifier {
  static const storageKey = 'blistra:themeMode';
  static const accentKey = 'blistra:accent';

  ThemeMode _mode = ThemeMode.system;
  AccentPalette _accent = AccentPalette.lagoon;

  ThemeMode get mode => _mode;
  AccentPalette get accent => _accent;
  bool get isDarkSelected => _mode == ThemeMode.dark;
  bool get isLightSelected => _mode == ThemeMode.light;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _mode = _parse(prefs.getString(storageKey));
      _accent = AccentPalette.fromName(prefs.getString(accentKey));
      notifyListeners();
    } catch (_) {
      // Best-effort cache: fall back to system + default accent.
    }
  }

  Future<void> setAccent(AccentPalette accent) async {
    if (_accent == accent) return;
    _accent = accent;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(accentKey, accent.name);
    } catch (_) {
      // Persistence is best-effort only.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, _encode(mode));
    } catch (_) {
      // Persistence is best-effort only.
    }
  }

  /// Toggles Light ↔ Dark. From System, resolves against [brightness] then
  /// stores the explicit opposite so the choice is stable and persisted.
  Future<void> toggle(Brightness brightness) {
    final effectiveDark = _mode == ThemeMode.dark ||
        (_mode == ThemeMode.system && brightness == Brightness.dark);
    return setMode(effectiveDark ? ThemeMode.light : ThemeMode.dark);
  }

  bool isDark(Brightness platformBrightness) =>
      _mode == ThemeMode.dark ||
      (_mode == ThemeMode.system && platformBrightness == Brightness.dark);

  static ThemeMode _parse(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  static String _encode(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };
}
