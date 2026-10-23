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

  static const String _apiBaseUrlDefine = String.fromEnvironment(
    'API_BASE_URL',
  );
  static const String _legacyDefine = String.fromEnvironment(
    'BACKEND_BASE_URL',
  );

  /// Whether a phone number must be verified with an SMS code. Off by default
  /// because only email delivery is configured; build with
  /// `--dart-define=REQUIRE_PHONE_VERIFICATION=true` once SMS is available.
  static bool requirePhoneVerification = const bool.fromEnvironment(
    'REQUIRE_PHONE_VERIFICATION',
  );

  /// Blistra AI is parked until launch; build with `--dart-define=AI_ENABLED=true`
  /// to turn the chat entry points back on.
  static const bool aiEnabled = bool.fromEnvironment('AI_ENABLED');

  /// Shown in Profile > Help. Keep in step with `version:` in pubspec.yaml,
  /// or override with `--dart-define=APP_VERSION=...` in release builds.
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// CI build number of this APK (`--dart-define=APP_BUILD=...`, set by the
  /// APK workflow to the same number as its `apk-<n>` release). 0 for local
  /// builds, which never prompt for updates.
  static const int appBuild = int.fromEnvironment('APP_BUILD');

  /// Support inbox shown in Profile > Help. Empty hides the email row; set
  /// with `--dart-define=SUPPORT_EMAIL=...`.
  static const String supportEmail = String.fromEnvironment('SUPPORT_EMAIL');

  static String get apiBaseUrl {
    if (_apiBaseUrlDefine.isNotEmpty) {
      return _stripTrailingSlash(_apiBaseUrlDefine);
    }
    if (_legacyDefine.isNotEmpty) {
      return _stripTrailingSlash(_legacyDefine);
    }
    if (kReleaseMode) {
      throw StateError(
        'Release builds require API_BASE_URL=https://your-api-host',
      );
    }
    if (!kIsWeb && Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://127.0.0.1:8080';
  }

  static String _stripTrailingSlash(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        (kReleaseMode &&
            (uri.scheme != 'https' ||
                uri.userInfo.isNotEmpty ||
                (uri.path.isNotEmpty && uri.path != '/') ||
                uri.hasQuery ||
                uri.hasFragment))) {
      throw StateError(
        'API_BASE_URL must be an HTTPS origin without credentials or a path.',
      );
    }
    var url = value;
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }
}
