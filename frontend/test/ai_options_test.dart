import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/ai/ai_api.dart';

void main() {
  test('Medicine schedule selections show dosing times and use the selected medicine', () async {
    const medicine = '00000000-0000-0000-0000-000000000002';
    final api = AiApi(
      ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/medicines/$medicine/schedules');
          return http.Response(
            jsonEncode([
              {
                'id': 'schedule',
                'scheduleType': 'DAILY',
                'times': ['08:00'],
              },
            ]),
            200,
          );
        }),
      ),
    );
    final path = AiApi.referencePath(
      {'reference': '/api/v1/medicines/{medicineId}/schedules'},
      {'medicineId': medicine},
    );
    expect(await api.options(path), [
      {'id': 'schedule', 'label': 'DAILY 08:00'},
    ]);
    expect(
      AiApi.referencePath({
        'reference': '/api/v1/medicines/{medicineId}/schedules',
      }, {}),
      isEmpty,
    );
  });

  test(
    'Shared expense participant selections use the selected group members',
    () async {
      const group = '00000000-0000-0000-0000-000000000003';
      final api = AiApi(
        ApiClient(
          baseUrl: 'http://localhost',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/api/v1/finance/groups/$group');
            return http.Response(
              jsonEncode({
                'members': [
                  {
                    'user': {'id': 'member', 'displayName': 'Alice'},
                  },
                ],
              }),
              200,
            );
          }),
        ),
      );
      final path = AiApi.referencePath(
        {'reference': '/api/v1/finance/friends'},
        {'groupId': group},
      );
      expect(await api.options(path), [
        {'id': 'member', 'label': 'Alice'},
      ]);
    },
  );

  test('Record selectors refuse arbitrary URLs and paths', () async {
    final api = AiApi(
      ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((_) async {
          fail('An unregistered selector must not issue a request.');
        }),
      ),
    );
    expect(await api.options('https://untrusted.example/private'), isEmpty);
    expect(await api.options('/api/v1/auth/export'), isEmpty);
    expect(
      await api.options('/api/v1/medicines/../../auth/schedules'),
      isEmpty,
    );
  });
}
