import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/features/medicines/data/medicines_api_client.dart';
import 'package:frontend/features/medicines/models/medicine_enums.dart';
import 'package:frontend/features/medicines/models/today_doses.dart';
import 'package:frontend/features/medicines/state/medicine_today_controller.dart';
import 'package:frontend/features/medicines/util/numbers.dart';

String _todayJson() => jsonEncode({
      'date': '2026-09-25',
      'totalDoses': 2,
      'takenDoses': 1,
      'remainingDoses': 1,
      'missedDoses': 0,
      'skippedDoses': 0,
      'nextDose': {
        'medicineId': 'med-1',
        'medicineName': 'Vitamin D',
        'scheduleId': 'sched-1',
        'scheduledAt': '2026-09-25T20:00:00+05:30',
        'status': 'PENDING',
        'takenAt': null,
        'doseAmount': '1',
        'doseUnit': 'tablet',
        'doseRecordId': null,
      },
      'doses': [
        {
          'medicineId': 'med-1',
          'medicineName': 'Vitamin D',
          'scheduleId': 'sched-1',
          'scheduledAt': '2026-09-25T08:00:00+05:30',
          'status': 'TAKEN',
          'takenAt': '2026-09-25T08:02:00+05:30',
          'doseAmount': '1',
          'doseUnit': 'tablet',
          'doseRecordId': 'dose-1',
        },
        {
          'medicineId': 'med-1',
          'medicineName': 'Vitamin D',
          'scheduleId': 'sched-1',
          'scheduledAt': '2026-09-25T20:00:00+05:30',
          'status': 'PENDING',
          'takenAt': null,
          'doseAmount': '1',
          'doseUnit': 'tablet',
          'doseRecordId': null,
        },
      ],
    });

MedicinesApiClient _client(MockClient mock) => MedicinesApiClient(
      httpClient: mock,
      baseUrl: 'http://test',
      tokenProvider: () => 't',
    );

void main() {
  group('trimNumber', () {
    test('trims redundant .0', () {
      expect(trimNumber(250), '250');
      expect(trimNumber(250.0), '250');
      expect(trimNumber(500.5), '500.5');
      expect(trimNumber(60), '60');
    });
  });

  group('MedicineToday.fromJson', () {
    test('parses summary, pending and taken doses', () {
      final today = MedicineToday.fromJson(
          jsonDecode(_todayJson()) as Map<String, dynamic>);
      expect(today.totalDoses, 2);
      expect(today.takenDoses, 1);
      expect(today.remainingDoses, 1);
      expect(today.isEmpty, isFalse);
      expect(today.allCompleted, isFalse);

      final taken = today.doses.first;
      expect(taken.isPending, isFalse);
      expect(taken.isTaken, isTrue);
      expect(taken.status, DoseStatus.taken);
      expect(taken.doseLabel, '1 tablet');
      expect(taken.doseRecordId, 'dose-1');

      final pending = today.doses.last;
      expect(pending.isPending, isTrue);
      expect(pending.status, isNull);

      expect(today.nextDose, isNotNull);
      expect(today.nextDose!.medicineName, 'Vitamin D');
    });

    test('empty day has no fake values', () {
      final today = MedicineToday.fromJson({
        'date': '2026-09-25',
        'totalDoses': 0,
        'takenDoses': 0,
        'remainingDoses': 0,
        'missedDoses': 0,
        'skippedDoses': 0,
        'nextDose': null,
        'doses': [],
      });
      expect(today.isEmpty, isTrue);
      expect(today.doses, isEmpty);
      expect(today.nextDose, isNull);
    });

    test('dose without amount has empty label', () {
      final dose = ExpectedDose(
        medicineId: 'm',
        medicineName: 'X',
        scheduledAt: DateTime(2026, 9, 25, 8, 0),
      );
      expect(dose.doseLabel, '');
    });
  });

  group('MedicinesApiClient.getTodayDoses', () {
    test('GETs /api/v1/medicines/today with date params', () async {
      String? path;
      Map<String, String>? query;
      final api = _client(MockClient((request) async {
        path = request.url.path;
        query = request.url.queryParameters;
        return http.Response(_todayJson(), 200);
      }));

      final today = await api.getTodayDoses(
          date: DateTime(2026, 9, 25), offsetMinutes: 330);

      expect(path, '/api/v1/medicines/today');
      expect(query?['date'], '2026-09-25');
      expect(query?['offsetMinutes'], '330');
      expect(today.totalDoses, 2);
    });
  });

  group('MedicineTodayController', () {
    test('refresh loads summary and doses', () async {
      final api = _client(MockClient((request) async {
        if (request.url.path == '/api/v1/medicines/today') {
          return http.Response(_todayJson(), 200);
        }
        return http.Response('{}', 404);
      }));
      final c = MedicineTodayController(api);
      await c.refresh();
      expect(c.error, isNull);
      expect(c.today, isNotNull);
      expect(c.today!.takenDoses, 1);
      expect(c.today!.doses.length, 2);
      c.dispose();
    });

    test('takeDose records pending past slot with slot instant', () async {
      String? postPath;
      Map<String, dynamic>? postBody;
      int todayCalls = 0;
      final api = _client(MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/medicines/today') {
          todayCalls++;
          return http.Response(_todayJson(), 200);
        }
        if (request.method == 'POST') {
          postPath = request.url.path;
          postBody =
              jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
              '{"id":"dose-2","medicineId":"med-1","scheduleId":"sched-1",'
              '"status":"TAKEN","scheduledAt":"2020-01-01T08:00:00+05:30",'
              '"takenAt":"2020-01-01T08:01:00+05:30"}',
              201);
        }
        return http.Response('{}', 404);
      }));
      final c = MedicineTodayController(api);
      await c.refresh();

      // A pending slot firmly in the past is actionable.
      final past = ExpectedDose(
        medicineId: 'med-1',
        medicineName: 'Vitamin D',
        scheduleId: 'sched-1',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      final ok = await c.takeDose(past);

      expect(ok, isTrue);
      expect(postPath, '/api/v1/medicines/med-1/doses');
      expect(postBody?['status'], 'TAKEN');
      expect(postBody?['scheduleId'], 'sched-1');
      expect(postBody?['scheduledAt'], isNotNull);
      // Today summary reloaded after recording.
      expect(todayCalls, 2);
      c.dispose();
    });

    test('takeDose refuses future slots without a network call',
        () async {
      int posts = 0;
      final api = _client(MockClient((request) async {
        if (request.url.path == '/api/v1/medicines/today') {
          return http.Response(_todayJson(), 200);
        }
        posts++;
        return http.Response('{}', 201);
      }));
      final c = MedicineTodayController(api);
      final future = ExpectedDose(
        medicineId: 'med-1',
        medicineName: 'Vitamin D',
        scheduledAt: DateTime.now().add(const Duration(hours: 3)),
      );
      expect(await c.takeDose(future), isFalse);
      expect(posts, 0);
      c.dispose();
    });

    test('duplicate recording surfaces the backend 409', () async {
      final api = _client(MockClient((request) async {
        if (request.url.path == '/api/v1/medicines/today') {
          return http.Response(_todayJson(), 200);
        }
        return http.Response(
            '{"code":"RESOURCE_ALREADY_EXISTS","message":"already recorded"}',
            409);
      }));
      final c = MedicineTodayController(api);
      final past = ExpectedDose(
        medicineId: 'med-1',
        medicineName: 'Vitamin D',
        scheduledAt: DateTime.now().subtract(const Duration(hours: 3)),
      );
      expect(await c.takeDose(past), isFalse);
      expect(c.recordError, isNotNull);
      c.dispose();
    });
  });
}
