/// Global search tests: real backend contract, grouping, result routing.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/routing/routes.dart';
import 'package:frontend/features/search/screens/search_screen.dart';
import 'package:frontend/features/search/search_api.dart';

SearchApi _apiWithResults(List<Map<String, dynamic>> results) {
  final mock = MockClient((req) async {
    if (req.method == 'GET' && req.url.path.endsWith('/search')) {
      return http.Response(
        jsonEncode({
          'results': results,
          'page': 0,
          'size': 20,
          'totalElements': results.length,
          'totalPages': 1,
          'last': true,
          'partial': false,
        }),
        200,
      );
    }
    return http.Response('{}', 404);
  });
  return SearchApi(ApiClient(baseUrl: 'http://localhost', httpClient: mock));
}

Map<String, dynamic> _result(
  String module,
  String type,
  String id,
  String title,
  String route,
) =>
    {
      'module': module,
      'type': type,
      'id': id,
      'title': title,
      'subtitle': '$title subtitle',
      'route': route,
    };

void main() {
  group('SearchApi', () {
    test('short queries never hit the network', () async {
      var hits = 0;
      final mock = MockClient((req) async {
        hits++;
        return http.Response('{}', 200);
      });
      final api =
          SearchApi(ApiClient(baseUrl: 'http://x', httpClient: mock));
      expect(await api.search(''), isEmpty);
      expect(await api.search('a'), isEmpty);
      expect(hits, 0);
    });

    test('parses backend results', () async {
      final api = _apiWithResults([
        _result('MEDICINES', 'MEDICINE', 'm1', 'Vitamin D',
            'medicines/m1'),
      ]);
      final results = await api.search('Vitamin');
      expect(results, hasLength(1));
      expect(results.single.title, 'Vitamin D');
      expect(results.single.route, 'medicines/m1');
    });
  });

  group('AppRoutes.resolveSearchRoute (search result destinations)', () {
    test('medicine result opens its detail page', () {
      final dest = AppRoutes.resolveSearchRoute('medicines/abc');
      expect(dest.tab, AppTab.medicines);
      expect(dest.detail, isNotNull);
    });

    test('meal result opens its detail page', () {
      final dest = AppRoutes.resolveSearchRoute('diet/meal/xyz');
      expect(dest.tab, AppTab.diet);
      expect(dest.detail, isNotNull);
    });

    test('unknown routes fall back to dashboard', () {
      final dest = AppRoutes.resolveSearchRoute('nonsense/xyz');
      expect(dest.tab, AppTab.dashboard);
    });
  });

  group('SearchScreen', () {
    testWidgets('groups real results and routes on tap', (tester) async {
      final api = _apiWithResults([
        _result('MEDICINES', 'MEDICINE', 'm1', 'Vitamin D',
            'medicines/m1'),
        _result('PLANNER', 'TASK', 't1', 'Buy Vitamin D',
            'planner/task/t1'),
      ]);
      String? opened;
      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(
            api: api,
            onOpenRoute: (route) => opened = route,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Vitamin');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Medicines'), findsOneWidget);
      expect(find.text('Planner'), findsOneWidget);
      expect(find.text('Vitamin D'), findsWidgets);

      await tester.tap(find.text('Vitamin D').first);
      await tester.pump();
      expect(opened, 'medicines/m1');
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty results show an explicit empty state',
        (tester) async {
      final api = _apiWithResults([]);
      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(api: api, onOpenRoute: (_) {}),
        ),
      );
      await tester.enterText(find.byType(TextField), 'zzz-no-match');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No results'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('backend failure shows retry', (tester) async {
      final mock = MockClient((req) async {
        return http.Response('boom', 500);
      });
      final api =
          SearchApi(ApiClient(baseUrl: 'http://x', httpClient: mock));
      await tester.pumpWidget(
        MaterialApp(
          home: SearchScreen(api: api, onOpenRoute: (_) {}),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Vitamin');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Search failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
