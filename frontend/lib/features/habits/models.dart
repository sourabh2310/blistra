/// Domain models for the habits feature.
///
/// All dates are parsed as UTC [DateTime]. Models are immutable and only
/// constructible from the backend JSON contract.
library;

enum HabitType { boolean, count, duration }

enum HabitStatus { active, paused, archived }

enum HabitFrequency { daily, weekly }

HabitType habitTypeFromJson(String value) =>
    HabitType.values.byName(value.toLowerCase());

HabitStatus habitStatusFromJson(String value) =>
    HabitStatus.values.byName(value.toLowerCase());

HabitFrequency habitFrequencyFromJson(String value) =>
    HabitFrequency.values.byName(value.toLowerCase());

String enumToJson(Enum value) => value.name.toUpperCase();

class Habit {
  const Habit({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.status,
    required this.targetValue,
    required this.targetUnit,
    required this.targetMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final HabitType type;
  final HabitStatus status;
  final String? targetValue;
  final String? targetUnit;
  final int? targetMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => status == HabitStatus.archived;
  bool get isActive => status == HabitStatus.active;

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        type: habitTypeFromJson(json['type'] as String),
        status: habitStatusFromJson(json['status'] as String),
        targetValue: json['targetValue'] as String?,
        targetUnit: json['targetUnit'] as String?,
        targetMinutes: json['targetMinutes'] as int?,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );
}

class Schedule {
  const Schedule({
    required this.id,
    required this.habitId,
    required this.frequency,
    required this.daysOfWeek,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String habitId;
  final HabitFrequency frequency;
  final List<String> daysOfWeek;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        id: json['id'] as String,
        habitId: json['habitId'] as String,
        frequency: habitFrequencyFromJson(json['frequency'] as String),
        daysOfWeek: (json['daysOfWeek'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );
}

class Completion {
  const Completion({
    required this.id,
    required this.habitId,
    required this.completedOn,
    required this.value,
    required this.durationMinutes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String habitId;
  final DateTime completedOn;
  final String? value;
  final int? durationMinutes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Completion.fromJson(Map<String, dynamic> json) => Completion(
        id: json['id'] as String,
        habitId: json['habitId'] as String,
        completedOn: DateTime.parse(json['completedOn'] as String).toUtc(),
        value: json['value'] as String?,
        durationMinutes: json['durationMinutes'] as int?,
        createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
        updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
      );
}

class HabitTodayResponse {
  const HabitTodayResponse({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.targetValue,
    required this.targetUnit,
    required this.targetMinutes,
    required this.schedule,
    required this.completedToday,
  });

  final String id;
  final String name;
  final String? description;
  final HabitType type;
  final String? targetValue;
  final String? targetUnit;
  final int? targetMinutes;
  final Schedule? schedule;
  final bool completedToday;

  factory HabitTodayResponse.fromJson(Map<String, dynamic> json) =>
      HabitTodayResponse(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        type: habitTypeFromJson(json['type'] as String),
        targetValue: json['targetValue'] as String?,
        targetUnit: json['targetUnit'] as String?,
        targetMinutes: json['targetMinutes'] as int?,
        schedule: json['schedule'] != null
            ? Schedule.fromJson(json['schedule'] as Map<String, dynamic>)
            : null,
        completedToday: json['completedToday'] as bool? ?? false,
      );
}

class HabitStatisticsResponse {
  const HabitStatisticsResponse({
    required this.totalCompletions,
    required this.currentStreak,
    required this.bestStreak,
    required this.lastCompletedOn,
  });

  final int totalCompletions;
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastCompletedOn;

  factory HabitStatisticsResponse.fromJson(Map<String, dynamic> json) =>
      HabitStatisticsResponse(
        totalCompletions: json['totalCompletions'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        bestStreak: json['bestStreak'] as int? ?? 0,
        lastCompletedOn: json['lastCompletedOn'] != null
            ? DateTime.parse(json['lastCompletedOn'] as String).toUtc()
            : null,
      );
}

class PageResult<T> {
  const PageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<T> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  bool get isEmpty => items.isEmpty;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemParser,
  ) =>
      PageResult(
        items: (json['content'] as List<dynamic>)
            .map((Object? item) => itemParser(item as Map<String, dynamic>))
            .toList(),
        page: json['page'] as int,
        size: json['size'] as int,
        totalElements: json['totalElements'] as int,
        totalPages: json['totalPages'] as int,
        last: json['last'] as bool,
      );
}