import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/features/medicines/data/medicines_api_client.dart';
import 'package:frontend/features/medicines/models/medicine_enums.dart';
import 'package:frontend/core/api/api_exception.dart';

void main() {
  group('MedicinesApiClient', () {
    late MedicinesApiClient client;
    late MockClient mockHttp;

    setUp(() {
      mockHttp = MockClient((request) async {
        // Default: 404 for unhandled
        return http.Response('{"code":"NOT_FOUND","message":"Not found"}', 404);
      });
      client = MedicinesApiClient(
        httpClient: mockHttp,
        baseUrl: 'http://localhost:8080',
        tokenProvider: () => 'test-token',
      );
    });

    tearDown(() {
      client.close();
    });

    group('listMedicines', () {
      test('GETs with query params and returns Page<Medicine>', () async {
        mockHttp = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/medicines');
          expect(request.url.queryParameters['page'], '0');
          expect(request.url.queryParameters['size'], '50');
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response('''
{
  "content": [
    {"id":"med-1","name":"Metformin","status":"ACTIVE","createdAt":"2026-01-01T08:00:00","updatedAt":"2026-01-01T08:00:00"},
    {"id":"med-2","name":"Aspirin","status":"PAUSED","createdAt":"2026-01-01T08:00:00","updatedAt":"2026-01-01T08:00:00"}
  ],
  "page": 0, "size": 50, "totalElements": 2, "totalPages": 1, "last": true
}''', 200);
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        final page = await client.listMedicines(page: 0, size: 50);

        expect(page.content.length, 2);
        expect(page.content.first.name, 'Metformin');
        expect(page.content.last.name, 'Aspirin');
        expect(page.totalElements, 2);
      });

      test('includes status filter when provided', () async {
        bool statusSent = false;
        mockHttp = MockClient((request) async {
          statusSent = request.url.queryParameters['status'] == 'ACTIVE';
          return http.Response('{"content":[],"page":0,"size":50,"totalElements":0,"totalPages":0,"last":true}', 200);
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        await client.listMedicines(status: MedicineStatus.active);
        expect(statusSent, isTrue);
      });
    });

    group('createMedicine', () {
      test('POSTs to /api/v1/medicines with body and returns Medicine', () async {
        mockHttp = MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/medicines');
          expect(request.body, contains('Metformin'));
          return http.Response('''
{"id":"med-new","name":"Metformin","status":"ACTIVE","createdAt":"2026-01-01T08:00:00","updatedAt":"2026-01-01T08:00:00"}
''', 201);
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        final med = await client.createMedicine({
          'name': 'Metformin',
          'status': 'ACTIVE',
        });

        expect(med.id, 'med-new');
        expect(med.name, 'Metformin');
      });
    });

    group('archiveMedicine', () {
      test('DELETEs with 204', () async {
        int statusCode = 0;
        mockHttp = MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/api/v1/medicines/med-1');
          statusCode = 204;
          return http.Response('', 204);
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        await client.archiveMedicine('med-1');
        expect(statusCode, 204);
      });
    });

    group('listSchedules', () {
      test('GETs array and returns List<Schedule>', () async {
        mockHttp = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/medicines/med-1/schedules');
          return http.Response('''
[
  {"id":"sched-1","medicineId":"med-1","scheduleType":"DAILY","times":["08:00"],"daysOfWeek":[],"doseAmount":500,"doseUnit":"mg","startDate":"2026-01-01","active":true,"createdAt":"2026-01-01T08:00:00","updatedAt":"2026-01-01T08:00:00"}
]
''', 200);
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        final schedules = await client.listSchedules('med-1');
        expect(schedules.length, 1);
        expect(schedules.first.scheduleType, ScheduleType.daily);
      });
    });

    group('listDoses', () {
      test('GETs page and returns Page<DoseRecord>', () async {
        mockHttp = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/medicines/med-1/doses');
          return http.Response('''
{
  "content": [
    {"id":"dose-1","medicineId":"med-1","status":"TAKEN","scheduledAt":"2026-01-01T08:00:00+05:30","takenAt":"2026-01-01T08:05:00+05:30","createdAt":"2026-01-01T08:05:00","updatedAt":"2026-01-01T08:05:00"}
  ],
  "page":0,"size":50,"totalElements":1,"totalPages":1,"last":true
}
''', 200);
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        final page = await client.listDoses('med-1', page: 0, size: 50);
        expect(page.content.length, 1);
        expect(page.content.first.status, DoseStatus.taken);
      });
    });

    group('listRefills', () {
      test('GETs array and returns List<Refill>', () async {
        mockHttp = MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/v1/medicines/med-1/refills');
          return http.Response('''
[
  {"id":"refill-1","medicineId":"med-1","refillDate":"2026-01-15","quantity":60,"remainingQuantity":60,"createdAt":"2026-01-15T10:00:00","updatedAt":"2026-01-15T10:00:00"}
]
''', 200);
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        final refills = await client.listRefills('med-1');
        expect(refills.length, 1);
        expect(refills.first.quantity, 60);
      });
    });

    group('error handling', () {
      test('throws ApiException on 400 with field errors', () async {
        mockHttp = MockClient((request) async {
          return http.Response('''
{"status":400,"code":"VALIDATION_ERROR","message":"Invalid request","errors":[{"field":"name","message":"Name is required"}]}
''', 400);
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        try {
          await client.listMedicines();
          fail('Expected exception');
        } on ApiException catch (e) {
          expect(e.statusCode, 400);
          expect(e.code, 'VALIDATION_ERROR');
          expect(e.fieldErrors['name'], 'Name is required');
        }
      });

      test('throws NetworkException on connection error', () async {
        mockHttp = MockClient((request) async {
          throw Exception('Connection refused');
        });
        client = MedicinesApiClient(
          httpClient: mockHttp,
          baseUrl: 'http://localhost:8080',
          tokenProvider: () => 'test-token',
        );

        try {
          await client.listMedicines();
          fail('Expected exception');
        } on NetworkException catch (e) {
          expect(e.cause.toString(), contains('Connection refused'));
        }
      });
    });
  });
}