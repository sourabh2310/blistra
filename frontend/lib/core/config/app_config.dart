import 'dart:io';

import 'package:flutter/foundation.dart';

/// Runtime configuration for the Blistra app.
///
/// The backend must be reachable from the device or emulator that runs the
/// app. Android emulators reach the host machine through 10.0.2.2, while every
/// other platform can use loopback directly. Override at run time with
/// `--dart-define=BACKEND_BASE_URL=...`.
class AppConfig {
  AppConfig._();

  static const String _dartDefineUrl = String.fromEnvironment('BACKEND_BASE_URL');

  static String get apiBaseUrl {
    if (_dartDefineUrl.isNotEmpty) {
      return _stripTrailingSlash(_dartDefineUrl);
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