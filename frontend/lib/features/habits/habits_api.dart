/// Typed client for the habits REST API.
library;

import '../../core/api/api_client.dart';
import 'models.dart';

class HabitsApi {
  HabitsApi({required this.apiClient});

  final ApiClient apiClient;

  Future<PageResult<Habit>> fetchHabits({
    HabitStatus? status,
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, dynamic> body = await apiClient.get(
      '/api/v1/habits',
      query: {
        if (status != null) 'status': enumToJson(status),
        'page': '$page',
        'size': '$size',
      },
    );
    return PageResult.fromJson(body, Habit.fromJson);
  }

  Future<Habit> createHabit({
    required String name,
    required HabitType type,
    String? description,
    String? targetValue,
    String? targetUnit,
    int? targetMinutes,
    HabitStatus? status,
  }) async {
    final Map<String, dynamic> body = await apiClient.post(
      '/api/v1/habits',
      body: {
        'name': name,
        'type': enumToJson(type),
        if (description != null && description.isNotEmpty)
          'description': description,
        'targetValue': ?targetValue,
        'targetUnit': ?targetUnit,
        'targetMinutes': ?targetMinutes,
        if (status != null) 'status': enumToJson(status),
      },
    );
    return Habit.fromJson(body);
  }

  Future<Habit> getHabit(String id) async {
    final Map<String, dynamic> body = await apiClient.get(
      '/api/v1/habits/$id',
    );
    return Habit.fromJson(body);
  }

  Future<Habit> updateHabit(
    String id, {
    required String name,
    required HabitType type,
    String? description,
    String? targetValue,
    String? targetUnit,
    int? targetMinutes,
    HabitStatus? status,
  }) async {
    final Map<String, dynamic> body = await apiClient.put(
      '/api/v1/habits/$id',
      body: {
        'name': name,
        'type': enumToJson(type),
        if (description != null && description.isNotEmpty)
          'description': description,
        'targetValue': ?targetValue,
        'targetUnit': ?targetUnit,
        'targetMinutes': ?targetMinutes,
        if (status != null) 'status': enumToJson(status),
      },
    );
    return Habit.fromJson(body);
  }

  Future<void> archiveHabit(String id) async {
    await apiClient.delete('/api/v1/habits/$id');
  }

  Future<List<HabitTodayResponse>> fetchTodayHabits() async {
    final List<dynamic> body = await apiClient.getList('/api/v1/habits/today');
    return body
        .map((Object? item) =>
            HabitTodayResponse.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Schedule> getSchedule(String habitId) async {
    final Map<String, dynamic> body = await apiClient.get(
      '/api/v1/habits/$habitId/schedule',
    );
    return Schedule.fromJson(body);
  }

  Future<Schedule> upsertSchedule(
    String habitId, {
    required HabitFrequency frequency,
    List<String>? daysOfWeek,
  }) async {
    final Map<String, dynamic> body = await apiClient.put(
      '/api/v1/habits/$habitId/schedule',
      body: {
        'frequency': enumToJson(frequency),
        'daysOfWeek': ?daysOfWeek,
      },
    );
    return Schedule.fromJson(body);
  }

  Future<Completion> recordCompletion(
    String habitId, {
    required DateTime completedOn,
    String? value,
    int? durationMinutes,
  }) async {
    final Map<String, dynamic> body = await apiClient.post(
      '/api/v1/habits/$habitId/completions',
      body: {
        'completedOn': _dateOnly(completedOn),
        'value': ?value,
        'durationMinutes': ?durationMinutes,
      },
    );
    return Completion.fromJson(body);
  }

  Future<void> removeCompletion(String habitId, DateTime completedOn) async {
    await apiClient.delete(
        '/api/v1/habits/$habitId/completions/${_dateOnly(completedOn)}');
  }

  Future<PageResult<Completion>> fetchCompletions(
    String habitId, {
    int page = 0,
    int size = 20,
  }) async {
    final Map<String, dynamic> body = await apiClient.get(
      '/api/v1/habits/$habitId/completions',
      query: {
        'page': '$page',
        'size': '$size',
      },
    );
    return PageResult.fromJson(body, Completion.fromJson);
  }

  Future<HabitStatisticsResponse> fetchStatistics(String habitId) async {
    final Map<String, dynamic> body = await apiClient.get(
      '/api/v1/habits/$habitId/statistics',
    );
    return HabitStatisticsResponse.fromJson(body);
  }

  static String _dateOnly(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}