import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/app_update/app_update_controller.dart';

const _apkUrl = 'https://github.com/o/r/releases/download/apk-7/blistra.apk';

http.Response _latest(Map<String, dynamic>? body) => body == null
    ? http.Response('', 204)
    : http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});

Map<String, dynamic> _release({int build = 7, int min = 0, String url = _apkUrl, int? size}) => {
      'buildNumber': build,
      'versionName': 'Blistra APK $build',
      'notes': 'Fixes',
      'downloadUrl': url,
      'sizeBytes': size,
      'minSupportedBuild': min,
    };

AppUpdateController _controller({
  required Map<String, dynamic>? latest,
  int currentBuild = 5,
  List<int>? apkBytes,
  Directory? dir,
  List<String>? opened,
}) {
  final client = MockClient((request) async {
    if (request.url.path == '/api/v1/app/latest') return _latest(latest);
    if (request.url.toString() == _apkUrl && apkBytes != null) {
      return http.Response.bytes(apkBytes, 200);
    }
    return http.Response('nope', 404);
  });
  return AppUpdateController(
    ApiClient(baseUrl: 'http://backend.test', httpClient: client),
    httpClient: client,
    currentBuild: currentBuild,
    platformSupported: true,
    downloadDir: () async => dir ?? Directory.systemTemp,
    openInstaller: (path) async {
      opened?.add(path);
      return null;
    },
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('offers a newer build and ignores same, older or untrusted ones', () async {
    expect(await _controller(latest: _release()).check(), isNotNull);
    expect(await _controller(latest: _release(build: 5)).check(), isNull);
    expect(await _controller(latest: null).check(), isNull);
    expect(
        await _controller(latest: _release(url: 'http://evil.test/x.apk')).check(),
        isNull);
  });

  test('dev builds (build 0) never check', () async {
    final c = _controller(latest: _release(), currentBuild: 0);
    expect(c.supported, isFalse);
    expect(await c.check(), isNull);
  });

  test('minSupportedBuild makes the update mandatory and ignores snooze', () async {
    final c = _controller(latest: _release(min: 6));
    await c.check();
    expect(c.mandatory, isTrue);
    await c.snooze();
    expect(await c.shouldPrompt(), isTrue);
  });

  test('Later snoozes this build for a day', () async {
    final c = _controller(latest: _release());
    await c.check();
    final now = DateTime(2026, 10, 17, 9);
    expect(await c.shouldPrompt(now: now), isTrue);
    await c.snooze(now: now);
    expect(await c.shouldPrompt(now: now.add(const Duration(hours: 3))), isFalse);
    expect(await c.shouldPrompt(now: now.add(const Duration(days: 1, minutes: 1))), isTrue);
  });

  test('downloads the APK, checks its size and opens the installer', () async {
    final dir = await Directory.systemTemp.createTemp('blistra_update');
    addTearDown(() => dir.delete(recursive: true));
    final opened = <String>[];
    final bytes = List<int>.generate(4096, (i) => i % 256);
    final c = _controller(
        latest: _release(size: bytes.length), apkBytes: bytes, dir: dir, opened: opened);
    await c.check();
    expect(await c.downloadAndInstall(), isTrue);
    expect(opened.single, endsWith('blistra-7.apk'));
    expect(await File(opened.single).length(), bytes.length);
    expect(c.progress, 1.0);

    final short = _controller(
        latest: _release(size: bytes.length + 1), apkBytes: bytes, dir: dir, opened: opened);
    await short.check();
    expect(await short.downloadAndInstall(), isFalse);
    expect(short.error, isNotNull);
  });
}
