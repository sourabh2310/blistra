import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exception.dart';
import 'package:frontend/features/habits/habits_api.dart';
import 'package:frontend/features/habits/models.dart';

const String _token = 'jwt-for-tests';

Map<String, dynamic> _requestToJson(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

http.Response _jsonResponse(Object? body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

ApiClient _clientWith(MockClient mock) =>
    ApiClient(baseUrl: 'http://backend.test', httpClient: mock);

void main() {
  group('HabitsApi habits', () {
    test('fetchHabits decodes a page', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/habits');
        expect(request.headers['authorization'], 'Bearer $_token');
        return _jsonResponse({
          'content': [
            {
              'id': 'h1',
              'name': 'Read 20 minutes',
              'description': 'Daily reading',
              'type': 'DURATION',
              'status': 'ACTIVE',
              'targetValue': null,
              'targetUnit': null,
              'targetMinutes': 20,
              'createdAt': '2026-09-01T08:00:00Z',
              'updatedAt': '2026-09-01T08:00:00Z',
            }
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
          'last': true,
        });
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      final PageResult<Habit> result = await api.fetchHabits();

      expect(result.totalElements, 1);
      final Habit habit = result.items.single;
      expect(habit.name, 'Read 20 minutes');
      expect(habit.type, HabitType.duration);
      expect(habit.status, HabitStatus.active);
      expect(habit.targetMinutes, 20);
      expect(habit.isActive, isTrue);
    });

    test('createHabit posts normalized payload and parses response', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/habits');
        final Map<String, dynamic> body = _requestToJson(request);
        expect(body, {
          'name': 'Glasses of water',
          'type': 'COUNT',
          'targetValue': '8',
          'targetUnit': 'glasses',
        });
        return _jsonResponse({
          'id': 'h2',
          'name': 'Glasses of water',
          'description': null,
          'type': 'COUNT',
          'status': 'ACTIVE',
          'targetValue': '8.0000',
          'targetUnit': 'glasses',
          'targetMinutes': null,
          'createdAt': '2026-09-02T08:00:00Z',
          'updatedAt': '2026-09-02T08:00:00Z',
        }, status: 201);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      final Habit created = await api.createHabit(
        name: 'Glasses of water',
        type: HabitType.count,
        targetValue: '8',
        targetUnit: 'glasses',
      );

      expect(created.id, 'h2');
      expect(created.type, HabitType.count);
      expect(created.targetValue, '8.0000');
      expect(created.targetUnit, 'glasses');
    });

    test('updateHabit posts updated fields', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/habits/h1');
        final Map<String, dynamic> body = _requestToJson(request);
        expect(body['name'], 'Read 30 minutes');
        expect(body['type'], 'DURATION');
        expect(body['targetMinutes'], 30);
        return _jsonResponse({
          'id': 'h1',
          'name': 'Read 30 minutes',
          'description': 'Daily reading',
          'type': 'DURATION',
          'status': 'ACTIVE',
          'targetValue': null,
          'targetUnit': null,
          'targetMinutes': 30,
          'createdAt': '2026-09-01T08:00:00Z',
          'updatedAt': '2026-09-03T08:00:00Z',
        });
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      final Habit updated = await api.updateHabit(
        'h1',
        name: 'Read 30 minutes',
        type: HabitType.duration,
        targetMinutes: 30,
      );

      expect(updated.targetMinutes, 30);
      expect(updated.name, 'Read 30 minutes');
    });

    test('archiveHabit deletes', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/habits/h1');
        return _jsonResponse(null, status: 204);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      await api.archiveHabit('h1');
    });
  });

  group('HabitsApi today', () {
    test('fetchTodayHabits returns list with schedule and completion state', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/habits/today');
        return _jsonResponse([
          {
            'id': 'h1',
            'name': 'Meditate',
            'description': '10 min mindfulness',
            'type': 'DURATION',
            'targetValue': null,
            'targetUnit': null,
            'targetMinutes': 10,
            'schedule': {
              'id': 's1',
              'habitId': 'h1',
              'frequency': 'DAILY',
              'daysOfWeek': [],
              'createdAt': '2026-09-01T08:00:00Z',
              'updatedAt': '2026-09-01T08:00:00Z',
            },
            'completedToday': false,
          }
        ]);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      final List<HabitTodayResponse> today = await api.fetchTodayHabits();

      expect(today, hasLength(1));
      expect(today.single.completedToday, isFalse);
      expect(today.single.schedule?.frequency, HabitFrequency.daily);
    });
  });

  group('HabitsApi schedule', () {
    test('upsertSchedule posts frequency and days', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/habits/h1/schedule');
        final Map<String, dynamic> body = _requestToJson(request);
        expect(body, {
          'frequency': 'WEEKLY',
          'daysOfWeek': ['MONDAY', 'WEDNESDAY', 'FRIDAY'],
        });
        return _jsonResponse({
          'id': 's1',
          'habitId': 'h1',
          'frequency': 'WEEKLY',
          'daysOfWeek': ['MONDAY', 'WEDNESDAY', 'FRIDAY'],
          'createdAt': '2026-09-01T08:00:00Z',
          'updatedAt': '2026-09-03T08:00:00Z',
        });
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      final Schedule schedule = await api.upsertSchedule(
        'h1',
        frequency: HabitFrequency.weekly,
        daysOfWeek: ['MONDAY', 'WEDNESDAY', 'FRIDAY'],
      );

      expect(schedule.frequency, HabitFrequency.weekly);
      expect(schedule.daysOfWeek, ['MONDAY', 'WEDNESDAY', 'FRIDAY']);
    });
  });

  group('HabitsApi completions', () {
    test('recordCompletion posts date-only and value', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/habits/h1/completions');
        final Map<String, dynamic> body = _requestToJson(request);
        expect(body['completedOn'], '2026-09-10');
        expect(body['value'], '5.0000');
        return _jsonResponse({
          'id': 'c1',
          'habitId': 'h1',
          'completedOn': '2026-09-10',
          'value': '5.0000',
          'durationMinutes': null,
          'createdAt': '2026-09-10T08:00:00Z',
          'updatedAt': '2026-09-10T08:00:00Z',
        }, status: 201);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      final Completion completion = await api.recordCompletion(
        'h1',
        completedOn: DateTime(2026, 9, 10),
        value: '5.0000',
      );

      expect(completion.value, '5.0000');
      expect(completion.completedOn, DateTime(2026, 9, 10).toUtc());
    });

    test('removeCompletion deletes with date-only path', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/api/v1/habits/h1/completions/2026-09-10');
        return _jsonResponse(null, status: 204);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      await api.removeCompletion('h1', DateTime(2026, 9, 10));
    });

    test('fetchCompletions parses page', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/habits/h1/completions');
        return _jsonResponse({
          'content': [
            {
              'id': 'c1',
              'habitId': 'h1',
              'completedOn': '2026-09-10',
              'value': '1.0000',
              'durationMinutes': null,
              'createdAt': '2026-09-10T08:00:00Z',
              'updatedAt': '2026-09-10T08:00:00Z',
            }
          ],
          'page': 0,
          'size': 20,
          'totalElements': 1,
          'totalPages': 1,
          'last': true,
        });
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      final PageResult<Completion> result =
          await api.fetchCompletions('h1', size: 20);

      expect(result.totalElements, 1);
      expect(result.items.single.value, '1.0000');
    });
  });

  group('HabitsApi statistics', () {
    test('fetchStatistics parses streak data', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/habits/h1/statistics');
        return _jsonResponse({
          'totalCompletions': 5,
          'currentStreak': 3,
          'bestStreak': 7,
          'lastCompletedOn': '2026-09-10',
        });
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final HabitsApi api = HabitsApi(apiClient: client);

      final HabitStatisticsResponse stats = await api.fetchStatistics('h1');

      expect(stats.totalCompletions, 5);
      expect(stats.currentStreak, 3);
      expect(stats.bestStreak, 7);
      expect(stats.lastCompletedOn, DateTime(2026, 9, 10).toUtc());
    });
  });

  group('HabitsApi errors and auth', () {
    test('maps validation errors to fieldErrors', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return _jsonResponse({
          'status': 400,
          'code': 'INVALID_REQUEST',
          'message': 'Validation failed',
          'path': '/api/v1/habits',
          'errors': [
            {'field': 'name', 'message': 'Name is required'}
          ],
        }, status: 400);
      });
      final ApiClient client = _clientWith(mock)..token = _token;

      try {
        await client.post('/api/v1/habits', body: {});
        fail('expected ApiException');
      } on ApiException catch (error) {
        expect(error.statusCode, 400);
        expect(error.isValidationError, isTrue);
        expect(error.code, 'INVALID_REQUEST');
        expect(error.fieldErrors['name'], 'Name is required');
      }
    });

    test('reports unauthorized without leaking state', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return _jsonResponse({
          'status': 401,
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Authentication required',
          'path': '/api/v1/habits',
        }, status: 401);
      });
      final ApiClient client = _clientWith(mock);

      try {
        await client.getList('/api/v1/habits');
        fail('expected ApiException');
      } on ApiException catch (error) {
        expect(error.isUnauthorized, isTrue);
      }
    });

    test('surfaces network failures as NetworkException', () async {
      final MockClient mock = MockClient((http.Request request) async {
        throw http.ClientException('connection refused');
      });
      final ApiClient client = _clientWith(mock);

      expect(
        () => client.getList('/api/v1/habits'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}