/// In-app update for sideloaded Android builds.
///
/// The backend reports the newest APK (GET /api/v1/app/latest); this
/// compares it with the build number stamped in at compile time
/// (`--dart-define=APP_BUILD=...`, set by the APK workflow), downloads the
/// APK with progress and hands it to Android's package installer. Android
/// always asks the user to confirm the install; there is no silent update
/// for apps outside a store.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';

class AppRelease {
  const AppRelease({
    required this.buildNumber,
    required this.versionName,
    required this.downloadUrl,
    this.notes,
    this.sizeBytes,
    this.minSupportedBuild = 0,
  });

  final int buildNumber;
  final String versionName;
  final String downloadUrl;
  final String? notes;
  final int? sizeBytes;
  final int minSupportedBuild;

  factory AppRelease.fromJson(Map<String, dynamic> json) => AppRelease(
        buildNumber: (json['buildNumber'] as num?)?.toInt() ?? 0,
        versionName: json['versionName'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
        notes: json['notes'] as String?,
        sizeBytes: (json['sizeBytes'] as num?)?.toInt(),
        minSupportedBuild: (json['minSupportedBuild'] as num?)?.toInt() ?? 0,
      );
}

class AppUpdateController extends ChangeNotifier {
  AppUpdateController(
    this._api, {
    http.Client? httpClient,
    int? currentBuild,
    bool? platformSupported,
    Future<Directory> Function()? downloadDir,
    Future<String?> Function(String path)? openInstaller,
  })  : _http = httpClient ?? http.Client(),
        currentBuild = currentBuild ?? AppConfig.appBuild,
        _platformSupported =
            platformSupported ?? (!kIsWeb && Platform.isAndroid),
        _downloadDir = downloadDir ?? getTemporaryDirectory,
        _openInstaller = openInstaller ?? _openWithAndroidInstaller;

  static const _snoozeKey = 'app_update_snoozed';
  static const snoozeFor = Duration(days: 1);

  final ApiClient _api;
  final http.Client _http;
  final bool _platformSupported;
  final Future<Directory> Function() _downloadDir;
  final Future<String?> Function(String path) _openInstaller;

  /// This install's build number; 0 for local/dev builds (never prompted).
  final int currentBuild;

  AppRelease? _available;
  bool _downloading = false;
  double? _progress;
  String? _error;

  /// Newest release when it is newer than this install, else null.
  AppRelease? get available => _available;
  bool get downloading => _downloading;

  /// 0..1 while downloading; null when the size is unknown.
  double? get progress => _progress;
  String? get error => _error;

  /// Whether this build can update itself at all.
  bool get supported => _platformSupported && currentBuild > 0;

  /// This install is too old to keep using; the prompt can't be dismissed.
  bool get mandatory =>
      _available != null && currentBuild < _available!.minSupportedBuild;

  /// Asks the backend for the newest build. Never throws: a failed check
  /// just means no prompt this time.
  Future<AppRelease?> check() async {
    if (!supported) return null;
    try {
      final json = await _api.getOptional('/api/v1/app/latest',
          query: const {'platform': 'android'});
      final release = json == null ? null : AppRelease.fromJson(json);
      _available = release != null &&
              release.buildNumber > currentBuild &&
              _isTrustedUrl(release.downloadUrl)
          ? release
          : null;
    } catch (_) {
      _available = null;
    }
    notifyListeners();
    return _available;
  }

  /// True when the prompt should show now: always for mandatory updates,
  /// otherwise unless the user chose "Later" for this build recently.
  Future<bool> shouldPrompt({DateTime? now}) async {
    final release = _available;
    if (release == null) return false;
    if (mandatory) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_snoozeKey);
      if (raw == null) return true;
      final parts = raw.split('@');
      final build = int.tryParse(parts.first);
      final at = DateTime.tryParse(parts.length > 1 ? parts[1] : '');
      if (build != release.buildNumber || at == null) return true;
      return (now ?? DateTime.now()).difference(at) >= snoozeFor;
    } catch (_) {
      return true;
    }
  }

  /// "Later": stay quiet about this build for [snoozeFor].
  Future<void> snooze({DateTime? now}) async {
    final release = _available;
    if (release == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_snoozeKey,
          '${release.buildNumber}@${(now ?? DateTime.now()).toIso8601String()}');
    } catch (_) {
      // Worst case the prompt shows again next launch.
    }
  }

  /// Downloads the APK and opens Android's installer. Returns false with
  /// [error] set when something went wrong.
  Future<bool> downloadAndInstall() async {
    final release = _available;
    if (release == null || _downloading) return false;
    _downloading = true;
    _progress = 0;
    _error = null;
    notifyListeners();
    IOSink? sink;
    File? file;
    try {
      final dir = await _downloadDir();
      file = File('${dir.path}/blistra-${release.buildNumber}.apk');
      final response = await _http
          .send(http.Request('GET', Uri.parse(release.downloadUrl)))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw HttpException('Download failed (HTTP ${response.statusCode})');
      }
      final total = response.contentLength ?? release.sizeBytes;
      sink = file.openWrite();
      var received = 0;
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 30))) {
        sink.add(chunk);
        received += chunk.length;
        _progress = total != null && total > 0 ? received / total : null;
        notifyListeners();
      }
      await sink.close();
      sink = null;
      if (release.sizeBytes != null && received != release.sizeBytes) {
        throw const FileSystemException('Download was incomplete');
      }
      final problem = await _openInstaller(file.path);
      if (problem != null) {
        _error = problem;
        return false;
      }
      return true;
    } catch (_) {
      await sink?.close();
      try {
        await file?.delete();
      } catch (_) {}
      _error = 'Couldn\'t download the update. Check your connection and try again.';
      return false;
    } finally {
      _downloading = false;
      notifyListeners();
    }
  }

  /// Only GitHub release downloads over HTTPS are accepted, so a tampered
  /// response can't point the installer somewhere else.
  static bool _isTrustedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    return uri.host == 'github.com' ||
        uri.host.endsWith('.githubusercontent.com');
  }

  static Future<String?> _openWithAndroidInstaller(String path) async {
    final result = await OpenFilex.open(path,
        type: 'application/vnd.android.package-archive');
    if (result.type == ResultType.done) return null;
    if (result.type == ResultType.permissionDenied) {
      return 'Allow Blistra to install apps: Settings > Apps > Blistra > '
          'Install unknown apps, then tap Update again.';
    }
    return 'Couldn\'t open the installer (${result.message}).';
  }
}
