import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/planner/models/schedule_view.dart';
import 'package:frontend/features/planner/planner_api.dart';
import 'package:frontend/features/planner/planner_controller.dart';

String _scheduleJson({String date = '2026-09-24'}) => jsonEncode({
      'date': date,
      'days': 1,
      'tasks': [
        {
          'id': 'task-1',
          'title': 'Morning gym',
          'status': 'TODO',
          'priority': 'HIGH',
          'dueDate': date,
          'dueAt': '${date}T06:00:00+05:30',
          'overdue': false,
        },
      ],
      'events': [
        {
          'id': 'ev-2',
          'title': 'Lunch',
          'status': 'SCHEDULED',
          'startAt': '${date}T13:00:00+05:30',
          'endAt': '${date}T14:00:00+05:30',
        },
        {
          'id': 'ev-1',
          'title': 'Standup',
          'status': 'SCHEDULED',
          'startAt': '${date}T10:00:00+05:30',
          'endAt': '${date}T10:30:00+05:30',
        },
      ],
    });

String _taskJson({String id = 'task-new', String status = 'TODO'}) => jsonEncode({
      'id': id,
      'title': 'Scheduled task',
      'status': status,
      'priority': 'MEDIUM',
      'overdue': false,
      'reminderMode': 'AT_START',
      'startAt': '2026-09-24T10:00:00Z',
      'endAt': '2026-09-24T11:00:00Z',
    });

String _taskPage() => jsonEncode({
      'content': [jsonDecode(_taskJson())],
      'page': 0,
      'size': 50,
      'totalElements': 1,
      'totalPages': 1,
      'last': true,
    });

String _eventJson(String id, String status) => jsonEncode({
      'id': id,
      'title': 'Gym',
      'status': status,
      'startAt': '2026-09-24T18:00:00+05:30',
      'endAt': '2026-09-24T19:00:00+05:30',
    });

PlannerController _controller(MockClient httpClient) {
  final apiClient = ApiClient(
    baseUrl: 'http://localhost:8080',
    httpClient: httpClient,
  )..token = 'test-token';
  return PlannerController(PlannerApi(apiClient));
}

void main() {
  group('ScheduleView', () {
    test('parses date, days, tasks and events', () {
      final view = ScheduleView.fromJson(
          jsonDecode(_scheduleJson()) as Map<String, dynamic>);
      expect(view.days, 1);
      expect(view.tasks.length, 1);
      expect(view.tasks.first.title, 'Morning gym');
      expect(view.events.length, 2);
    });

    test('tolerates empty schedule (empty day)', () {
      final view = ScheduleView.fromJson({
        'date': '2026-09-24',
        'days': 1,
        'tasks': [],
        'events': [],
      });
      expect(view.tasks, isEmpty);
      expect(view.events, isEmpty);
    });

    test('scope maps to day/week day counts', () {
      expect(ScheduleScope.day.days, 1);
      expect(ScheduleScope.week.days, 7);
    });
  });

  group('PlannerApi schedule', () {
    test('schedule sends date and days query params', () async {
      String? path;
      Map<String, String>? query;
      final client = MockClient((request) async {
        path = request.url.path;
        query = request.url.queryParameters;
        return http.Response(_scheduleJson(), 200);
      });
      final api = PlannerApi(ApiClient(
        baseUrl: 'http://localhost:8080',
        httpClient: client,
      )..token = 't');
      final view = await api.schedule(
          date: DateTime(2026, 9, 24), days: 7);
      expect(path, '/api/v1/planner/schedule');
      expect(query?['date'], '2026-09-24');
      expect(query?['days'], '7');
      expect(view.events.length, 2);
    });

    test('completeEvent posts to complete endpoint', () async {
      String? path;
      String? method;
      final client = MockClient((request) async {
        path = request.url.path;
        method = request.method;
        return http.Response(_eventJson('ev-1', 'COMPLETED'), 200);
      });
      final api = PlannerApi(ApiClient(
        baseUrl: 'http://localhost:8080',
        httpClient: client,
      )..token = 't');
      final event = await api.completeEvent('ev-1');
      expect(method, 'POST');
      expect(path, '/api/v1/planner/events/ev-1/complete');
      expect(event.title, 'Gym');
    });
  });

  group('PlannerController schedule navigation', () {
    test('loadSchedule orders events by start time', () async {
      final client = MockClient((request) async {
        final p = request.url.path;
        if (p == '/api/v1/planner/schedule') {
          return http.Response(_scheduleJson(), 200);
        }
        return http.Response('{}', 404);
      });
      final controller = _controller(client);
      await controller.loadSchedule();
      expect(controller.scheduleError, isNull);
      expect(controller.scheduleEventsOrdered.length, 2);
      expect(controller.scheduleEventsOrdered.first.title, 'Standup');
      expect(controller.scheduleEventsOrdered.last.title, 'Lunch');
    });

    test('next/previous day reload the schedule for the new date',
        () async {
      final requestedDates = <String?>[];
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/planner/schedule') {
          requestedDates.add(request.url.queryParameters['date']);
          final date = request.url.queryParameters['date']!;
          return http.Response(_scheduleJson(date: date), 200);
        }
        return http.Response('{}', 404);
      });
      final controller = _controller(client);
      final start = controller.selectedDate;
      await controller.nextDay();
      expect(controller.selectedDate,
          start.add(const Duration(days: 1)));
      await controller.previousDay();
      await controller.previousDay();
      expect(controller.selectedDate,
          start.subtract(const Duration(days: 1)));
      expect(requestedDates.length, 3);
      expect(requestedDates.toSet().length, 3);
    });

    test('search query filters schedule events', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/planner/schedule') {
          return http.Response(_scheduleJson(), 200);
        }
        return http.Response('{}', 404);
      });
      final controller = _controller(client);
      await controller.loadSchedule();
      controller.setSearchQuery('lunch');
      expect(controller.scheduleEventsOrdered.length, 1);
      expect(controller.scheduleEventsOrdered.first.title, 'Lunch');
      controller.setSearchQuery('');
      expect(controller.scheduleEventsOrdered.length, 2);
    });

    test('empty day yields empty ordered lists', () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/planner/schedule') {
          return http.Response(
              jsonEncode({
                'date': '2026-09-30',
                'days': 1,
                'tasks': [],
                'events': [],
              }),
              200);
        }
        return http.Response('{}', 404);
      });
      final controller = _controller(client);
      await controller.selectDate(DateTime(2026, 9, 30));
      expect(controller.scheduleEventsOrdered, isEmpty);
      expect(controller.scheduleTasksOrdered, isEmpty);
    });
  });

  group('Planner mutation refresh', () {
    test('task creation refreshes Today and shared Dashboard, then syncs reminders', () async {
      var dashboardRefreshes = 0;
      var reminderSyncs = 0;
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add('${request.method} ${request.url.path}');
        if (request.method == 'POST' && request.url.path == '/api/v1/planner/tasks') {
          return http.Response(_taskJson(), 201);
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/planner/tasks') {
          return http.Response(_taskPage(), 200);
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/planner/today') {
          return http.Response(jsonEncode({'overdueTasks': [], 'todayTasks': [], 'todayEvents': []}), 200);
        }
        return http.Response('{}', 404);
      });
      final apiClient = ApiClient(baseUrl: 'http://localhost:8080', httpClient: client)..token = 't';
      final controller = PlannerController(
        PlannerApi(apiClient),
        onRemindersChanged: () async {
          reminderSyncs++;
        },
        onDashboardChanged: () async {
          dashboardRefreshes++;
        },
      );
      await controller.createTask(
        title: 'Scheduled task',
        startAt: DateTime.utc(2026, 9, 24, 10),
        endAt: DateTime.utc(2026, 9, 24, 11),
      );
      expect(controller.tasks, hasLength(1));
      expect(controller.today, isNotNull);
      expect(reminderSyncs, 1);
      expect(dashboardRefreshes, 1);
      expect(paths, contains('GET /api/v1/planner/today'));
    });

    test('task mutation refreshes an already loaded schedule', () async {
      var scheduleLoads = 0;
      final client = MockClient((request) async {
        if (request.url.path == '/api/v1/planner/schedule') {
          scheduleLoads++;
          return http.Response(jsonEncode({'date': '2026-09-24', 'days': 1, 'tasks': [], 'events': []}), 200);
        }
        if (request.method == 'POST' && request.url.path == '/api/v1/planner/tasks/task-1/complete') {
          return http.Response(_taskJson(id: 'task-1', status: 'COMPLETED'), 200);
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/planner/tasks') {
          return http.Response(_taskPage(), 200);
        }
        if (request.method == 'GET' && request.url.path == '/api/v1/planner/today') {
          return http.Response(jsonEncode({'overdueTasks': [], 'todayTasks': [], 'todayEvents': []}), 200);
        }
        return http.Response('{}', 404);
      });
      final controller = _controller(client);
      await controller.loadSchedule();
      await controller.completeTask('task-1');
      expect(scheduleLoads, 2);
    });
  });
}
