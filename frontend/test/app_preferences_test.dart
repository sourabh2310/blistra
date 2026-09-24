/// Home/navigation customization tests: identifier rules + controller.
///
/// The backend re-validates the same rules server-side (see
/// AppPreferencesService); these tests pin the client-side mirror and the
/// controller's cache/save behavior.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/preferences/preferences_api.dart';
import 'package:frontend/features/preferences/preferences_controller.dart';
import 'package:frontend/features/preferences/shell_destinations.dart';

PreferencesController _controllerWithMock({
  Map<String, dynamic>? getPayload,
  int putStatus = 200,
}) {
  final mock = MockClient((req) async {
    if (req.method == 'GET' && req.url.path.endsWith('/preferences')) {
      return http.Response(
        jsonEncode(
          getPayload ??
              {
                'bottomNav': ['HOME', 'PLANNER', 'ADD', 'HEALTH', 'HUB'],
                'homeWidgets': ['DAY_AT_A_GLANCE', 'HEALTH', 'DIET'],
              },
        ),
        200,
      );
    }
    if (req.method == 'PUT' && req.url.path.endsWith('/preferences')) {
      // Echo the validated body back, like the backend does.
      return http.Response(req.body, putStatus);
    }
    return http.Response('{}', 404);
  });
  final api =
      PreferencesApi(ApiClient(baseUrl: 'http://localhost', httpClient: mock));
  return PreferencesController(api);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ShellDestinations.normalizeNav', () {
    test('defaults are valid', () {
      expect(
        ShellDestinations.normalizeNav(ShellDestinations.defaults),
        ['HOME', 'PLANNER', 'ADD', 'HEALTH', 'HUB'],
      );
    });

    test('Home cannot be removed', () {
      expect(
        () => ShellDestinations.normalizeNav(['PLANNER', 'ADD', 'HUB']),
        throwsArgumentError,
      );
    });

    test('Add cannot be removed', () {
      expect(
        () => ShellDestinations.normalizeNav(['HOME', 'PLANNER', 'HUB']),
        throwsArgumentError,
      );
    });

    test('maximum 5 items', () {
      expect(
        () => ShellDestinations.normalizeNav(
            ['HOME', 'PLANNER', 'ADD', 'HEALTH', 'HUB', 'DIET']),
        throwsArgumentError,
      );
    });

    test('unknown destination rejected', () {
      expect(
        () => ShellDestinations.normalizeNav(['HOME', 'ADD', 'ADMIN']),
        throwsArgumentError,
      );
    });

    test('duplicates collapsed', () {
      expect(
        ShellDestinations.normalizeNav(['HOME', 'ADD', 'HUB', 'HUB']),
        ['HOME', 'ADD', 'HUB'],
      );
    });
  });

  group('HomeWidgets.normalizeWidgets', () {
    test('hero stays first', () {
      final normalized = HomeWidgets.normalizeWidgets(['DIET', 'HEALTH']);
      expect(normalized.first, 'DAY_AT_A_GLANCE');
      expect(normalized, containsAll(['HEALTH', 'DIET']));
    });

    test('unknown widget rejected', () {
      expect(
        () => HomeWidgets.normalizeWidgets(
            ['DAY_AT_A_GLANCE', 'FAKE_FEATURE']),
        throwsArgumentError,
      );
    });

    test('empty rejected', () {
      expect(
        () => HomeWidgets.normalizeWidgets([]),
        throwsArgumentError,
      );
    });
  });

  group('PreferencesController', () {
    test('bindUser(null) restores defaults', () async {
      final controller = _controllerWithMock();
      await controller.bindUser(null);
      expect(controller.bottomNav, ShellDestinations.defaults);
      expect(controller.homeWidgets, HomeWidgets.defaults);
    });

    test('refresh loads the user payload', () async {
      final controller = _controllerWithMock();
      await controller.bindUser('alice@example.com');
      expect(controller.bottomNav,
          ['HOME', 'PLANNER', 'ADD', 'HEALTH', 'HUB']);
      expect(controller.homeWidgets.first, 'DAY_AT_A_GLANCE');
    });

    test('save persists valid configuration', () async {
      final controller = _controllerWithMock();
      await controller.bindUser('alice@example.com');
      final ok = await controller.save(
        bottomNav: ['HOME', 'ADD', 'HABITS', 'DIET', 'HUB'],
        homeWidgets: ['HEALTH', 'DIET'],
      );
      expect(ok, isTrue);
      expect(controller.bottomNav,
          ['HOME', 'ADD', 'HABITS', 'DIET', 'HUB']);
      // Hero is always kept first.
      expect(controller.homeWidgets.first, 'DAY_AT_A_GLANCE');
    });

    test('save rejects removing Home before any network call', () async {
      var hits = 0;
      final mock = MockClient((req) async {
        hits++;
        return http.Response('{}', 200);
      });
      final controller = PreferencesController(
          PreferencesApi(ApiClient(baseUrl: 'http://x', httpClient: mock)));
      await controller.bindUser('bob@example.com');
      expect(
        () => controller.save(
          bottomNav: ['ADD', 'HUB'],
          homeWidgets: ['DAY_AT_A_GLANCE'],
        ),
        throwsArgumentError,
      );
      expect(hits, 0);
    });

    test('resetToDefaults restores deterministic defaults', () async {
      final controller = _controllerWithMock();
      await controller.bindUser('alice@example.com');
      await controller.save(
        bottomNav: ['HOME', 'ADD', 'FINANCE'],
        homeWidgets: ['HEALTH'],
      );
      final ok = await controller.resetToDefaults();
      expect(ok, isTrue);
      expect(controller.bottomNav, ShellDestinations.defaults);
      expect(controller.homeWidgets, HomeWidgets.defaults);
    });

    test('cache restores the same user after restart', () async {
      final first = _controllerWithMock();
      await first.bindUser('carol@example.com');
      await first.save(
        bottomNav: ['HOME', 'ADD', 'FINANCE'],
        homeWidgets: ['HEALTH', 'FINANCE'],
      );
      // A fresh controller (new app start) with an unreachable backend
      // falls back to the per-user cache.
      final failing = MockClient((req) async {
        return http.Response('boom', 500);
      });
      final second = PreferencesController(PreferencesApi(
          ApiClient(baseUrl: 'http://x', httpClient: failing)));
      await second.bindUser('carol@example.com');
      expect(second.bottomNav, contains('FINANCE'));
    });
  });
}
