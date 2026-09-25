import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exception.dart';
import 'package:frontend/features/health/health_api.dart';
import 'package:frontend/features/health/health_models.dart';

void main() {
  group('HealthApi', () {
    late MockClient mockClient;
    late ApiClient apiClient;
    late HealthApi healthApi;

    setUp(() {
      mockClient = MockClient((request) async {
        // Default 404
        return http.Response('{}', 404);
      });
      apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
      healthApi = HealthApi(apiClient);
    });

    tearDown(() {
      mockClient.close();
      apiClient.close();
    });

    group('getProfile', () {
      test('returns profile on 200', () async {
        mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/health/profile' && request.method == 'GET') {
            return http.Response(
              '{"id":"p-1","heightCm":180,"bloodType":"O_POSITIVE",'
              '"dateOfBirth":"1990-01-01","createdAt":"2024-01-01T00:00:00Z",'
              '"updatedAt":"2024-01-01T00:00:00Z"}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
        healthApi = HealthApi(apiClient);

        final profile = await healthApi.getProfile();
        expect(profile, isNotNull);
        expect(profile!.id, 'p-1');
        expect(profile.heightCm, 180);
        expect(profile.bloodType, BloodType.oPositive);
      });

      test('returns null on 404', () async {
        mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/health/profile') {
            return http.Response('', 404);
          }
          return http.Response('{}', 404);
        });
        apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
        healthApi = HealthApi(apiClient);

        final profile = await healthApi.getProfile();
        expect(profile, isNull);
      });

      test('rethrows non-404 errors', () async {
        mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/health/profile') {
            return http.Response('{"code":"INTERNAL_ERROR","message":"DB down"}', 500,
                headers: {'content-type': 'application/json'});
          }
          return http.Response('{}', 404);
        });
        apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
        healthApi = HealthApi(apiClient);

        expect(() => healthApi.getProfile(), throwsA(isA<ApiException>()));
      });
    });

    group('listMeasurements', () {
      test('sends query params and parses page', () async {
        mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/health/measurements') {
            final query = request.url.queryParameters;
            expect(query['page'], '0');
            expect(query['size'], '20');
            expect(query['type'], 'WEIGHT');
            expect(query['from'], isNotNull);
            expect(query['to'], isNotNull);
            return http.Response(
              '{"content":[{"id":"m-1","type":"WEIGHT","measuredAt":"2024-01-01T08:00:00Z",'
              '"value":70,"unit":"KG","valueDiastolic":null,"source":null,"notes":null,'
              '"createdAt":null,"updatedAt":null}],"page":0,"size":20,"totalElements":1,'
              '"totalPages":1,"last":true}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
        healthApi = HealthApi(apiClient);

        final page = await healthApi.listMeasurements(
          type: MeasurementType.weight,
          from: DateTime.parse('2024-01-01T00:00:00Z'),
          to: DateTime.parse('2024-01-31T23:59:59Z'),
        );
        expect(page.content.length, 1);
        expect(page.content.first.type, MeasurementType.weight);
      });
    });

    group('createMeasurement', () {
      test('POSTs measurement and returns created', () async {
        mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/health/measurements' &&
              request.method == 'POST') {
            final body = request.body;
            expect(body, contains('"type":"WEIGHT"'));
            expect(body, contains('"value":70'));
            expect(body, contains('"unit":"KG"'));
            return http.Response(
              '{"id":"m-new","type":"WEIGHT","measuredAt":"2024-01-01T08:00:00Z",'
              '"value":70,"unit":"KG","valueDiastolic":null,"source":null,"notes":null,'
              '"createdAt":"2024-01-01T08:00:00Z","updatedAt":"2024-01-01T08:00:00Z"}',
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
        healthApi = HealthApi(apiClient);

        final input = MeasurementInput(
          type: MeasurementType.weight,
          measuredAt: DateTime.parse('2024-01-01T08:00:00Z'),
          value: 70,
          unit: 'KG',
        );
        final created = await healthApi.createMeasurement(input);
        expect(created.id, 'm-new');
        expect(created.value, 70);
      });
    });

    group('updateMeasurement', () {
      test('PUTs to /measurements/{id}', () async {
        mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/health/measurements/m-1' &&
              request.method == 'PUT') {
            return http.Response(
              '{"id":"m-1","type":"WEIGHT","measuredAt":"2024-01-01T08:00:00Z",'
              '"value":71,"unit":"KG","valueDiastolic":null,"source":null,"notes":null,'
              '"createdAt":"2024-01-01T08:00:00Z","updatedAt":"2024-01-02T08:00:00Z"}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
        healthApi = HealthApi(apiClient);

        final input = MeasurementInput(
          type: MeasurementType.weight,
          measuredAt: DateTime.parse('2024-01-01T08:00:00Z'),
          value: 71,
          unit: 'KG',
        );
        final updated = await healthApi.updateMeasurement('m-1', input);
        expect(updated.value, 71);
      });
    });

    group('deleteMeasurement', () {
      test('DELETEs /measurements/{id} and expects 204', () async {
        bool deleted = false;
        mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/health/measurements/m-1' &&
              request.method == 'DELETE') {
            deleted = true;
            return http.Response('', 204);
          }
          return http.Response('{}', 404);
        });
        apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
        healthApi = HealthApi(apiClient);

        await healthApi.deleteMeasurement('m-1');
        expect(deleted, isTrue);
      });
    });

    group('Blood pressure unit validation', () {
      test('createMeasurement uses MMHG for BP', () async {
        String? capturedBody;
        mockClient = MockClient((request) async {
          if (request.url.path == '/api/v1/health/measurements') {
            capturedBody = request.body;
            return http.Response(
              '{"id":"m-new","type":"BLOOD_PRESSURE","measuredAt":"2024-01-01T08:00:00Z",'
              '"value":120,"valueDiastolic":80,"unit":"MMHG","source":null,"notes":null,'
              '"createdAt":null,"updatedAt":null}',
              201,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('{}', 404);
        });
        apiClient = ApiClient(baseUrl: 'http://backend.test', httpClient: mockClient)..token = 'test-token';
        healthApi = HealthApi(apiClient);

        final input = MeasurementInput(
          type: MeasurementType.bloodPressure,
          measuredAt: DateTime.now(),
          value: 120,
          valueDiastolic: 80,
          unit: 'MMHG',
        );
        await healthApi.createMeasurement(input);
        expect(capturedBody, contains('"unit":"MMHG"'));
        expect(capturedBody, contains('"valueDiastolic":80'));
      });
    });
  });
}