import 'dart:io';

import 'package:flutter/foundation.dart';

/// Single runtime configuration for the Blistra app.
///
/// The backend must be reachable from the device or emulator that runs the
/// app. Android emulators reach the host machine through 10.0.2.2, while every
/// other platform can use loopback directly.
///
/// Override at run time with `--dart-define=API_BASE_URL=...`
/// (`BACKEND_BASE_URL` is accepted as a legacy alias). The value is the
/// scheme + host only (no `/api/v1` suffix); every API client appends full
/// `/api/v1/...` paths.
class AppConfig {
  AppConfig._();

  static const String _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');
  static const String _legacyDefine = String.fromEnvironment('BACKEND_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrlDefine.isNotEmpty) {
      return _stripTrailingSlash(_apiBaseUrlDefine);
    }
    if (_legacyDefine.isNotEmpty) {
      return _stripTrailingSlash(_legacyDefine);
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  static String _stripTrailingSlash(String value) {
    var url = value;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
