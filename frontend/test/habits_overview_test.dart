import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/habits/habits_api.dart';
import 'package:frontend/features/habits/habits_controller.dart';
import 'package:frontend/features/habits/models.dart';

Habit _habit(String id, String name) => Habit(
      id: id,
      name: name,
      description: null,
      type: HabitType.boolean,
      status: HabitStatus.active,
      targetValue: null,
      targetUnit: null,
      targetMinutes: null,
      createdAt: DateTime.utc(2026, 9, 20),
      updatedAt: DateTime.utc(2026, 9, 20),
    );

HabitTodayResponse _today(String id, String name, bool done) =>
    HabitTodayResponse(
      id: id,
      name: name,
      description: null,
      type: HabitType.boolean,
      targetValue: null,
      targetUnit: null,
      targetMinutes: null,
      schedule: null,
      completedToday: done,
    );

class _FakeHabitsApi extends HabitsApi {
  _FakeHabitsApi()
      : super(
          apiClient: ApiClient(
            baseUrl: 'http://test',
            httpClient: MockClient((_) async => http.Response('{}', 200)),
          ),
        );

  List<Habit> habits = [_habit('h1', 'Read')];
  List<HabitTodayResponse> today = [
    _today('h1', 'Read', true),
    _today('h2', 'Exercise', false),
  ];
  int todayCalls = 0;

  @override
  Future<PageResult<Habit>> fetchHabits(
      {HabitStatus? status, int page = 0, int size = 20}) async {
    return PageResult<Habit>(
      items: List.of(habits),
      page: 0,
      size: 20,
      totalElements: habits.length,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<List<HabitTodayResponse>> fetchTodayHabits() async {
    todayCalls++;
    return List.of(today);
  }

  @override
  Future<Habit> createHabit({
    required String name,
    required HabitType type,
    String? description,
    String? targetValue,
    String? targetUnit,
    int? targetMinutes,
    HabitStatus? status,
  }) async {
    final created = _habit('h-new', name);
    habits = [...habits, created];
    return created;
  }

  @override
  Future<Completion> recordCompletion(
    String habitId, {
    required DateTime completedOn,
    String? value,
    int? durationMinutes,
  }) async {
    today = [
      for (final t in today)
        t.id == habitId ? _today(t.id, t.name, true) : t,
    ];
    return Completion(
      id: 'c1',
      habitId: habitId,
      completedOn: completedOn,
      value: value,
      durationMinutes: durationMinutes,
      createdAt: DateTime.utc(2026, 9, 24),
      updatedAt: DateTime.utc(2026, 9, 24),
    );
  }

  @override
  Future<void> removeCompletion(
      String habitId, DateTime completedOn) async {
    today = [
      for (final t in today)
        t.id == habitId ? _today(t.id, t.name, false) : t,
    ];
  }
}

void main() {
  group('HabitStatisticsResponse', () {
    test('parses completion rate and occurrences', () {
      const stats = {
        'totalCompletions': 23,
        'currentStreak': 7,
        'bestStreak': 14,
        'lastCompletedOn': '2026-09-24',
        'dueOccurrences': 28,
        'completedDueOccurrences': 23,
        'completionRate': 0.8214,
      };
      final parsed = HabitStatisticsResponse.fromJson(stats);
      expect(parsed.totalCompletions, 23);
      expect(parsed.completionRateLabel, '82%');
      expect(parsed.occurrencesLabel, '23 / 28 occurrences');
    });

    test('missing analytics fields stay null (backward compatible)', () {
      const stats = {
        'totalCompletions': 0,
        'currentStreak': 0,
        'bestStreak': 0,
      };
      final parsed = HabitStatisticsResponse.fromJson(stats);
      expect(parsed.completionRateLabel, isNull);
      expect(parsed.occurrencesLabel, isNull);
      expect(parsed.lastCompletedOn, isNull);
    });
  });

  group('HabitsController overview', () {
    test('today counts derive from loaded data', () async {
      final controller =
          HabitsController(api: _FakeHabitsApi());
      await controller.loadAll();
      expect(controller.todayHabits.length, 2);
      expect(controller.doneToday.length, 1);
      expect(controller.dueToday.length, 1);
      controller.dispose();
    });

    test('create refreshes habits and notifies', () async {
      int notified = 0;
      final controller = HabitsController(
        api: _FakeHabitsApi(),
        onMutated: () async {
          notified++;
        },
      );
      await controller.loadAll();
      await controller.createHabit(name: 'Meditate', type: HabitType.boolean);
      expect(controller.habits.any((h) => h.name == 'Meditate'), isTrue);
      expect(notified, 1);
      controller.dispose();
    });

    test('complete reloads today and notifies dashboard', () async {
      int notified = 0;
      final api = _FakeHabitsApi();
      final controller = HabitsController(
        api: api,
        onMutated: () async {
          notified++;
        },
      );
      await controller.loadAll();
      final before = api.todayCalls;
      await controller.recordCompletion('h2',
          completedOn: DateTime.now().toUtc());
      expect(api.todayCalls, before + 1);
      expect(controller.doneToday.length, 2);
      expect(notified, 1);
      controller.dispose();
    });

    test('undo reloads today and notifies dashboard', () async {
      int notified = 0;
      final api = _FakeHabitsApi();
      final controller = HabitsController(
        api: api,
        onMutated: () async {
          notified++;
        },
      );
      await controller.loadAll();
      await controller.removeCompletion('h1', DateTime.now().toUtc());
      expect(controller.dueToday.length, 2);
      expect(notified, 1);
      controller.dispose();
    });
  });
}
