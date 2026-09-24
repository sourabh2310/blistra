import 'planner_event.dart';
import 'task.dart';

/// Planner-owned schedule for an explicit calendar window, mirroring
/// the backend `ScheduleResponse` (tasks due + overlapping events only).
class ScheduleView {
  ScheduleView({
    required this.date,
    required this.days,
    required this.tasks,
    required this.events,
  });

  final DateTime date;
  final int days;
  final List<PlannerTask> tasks;
  final List<PlannerEvent> events;

  factory ScheduleView.fromJson(Map<String, dynamic> json) {
    return ScheduleView(
      date: DateTime.parse(json['date'] as String),
      days: (json['days'] as num?)?.toInt() ?? 1,
      tasks: [
        if (json['tasks'] is List)
          for (final item in json['tasks'] as List)
            if (item is Map<String, dynamic>) PlannerTask.fromJson(item),
      ],
      events: [
        if (json['events'] is List)
          for (final item in json['events'] as List)
            if (item is Map<String, dynamic>) PlannerEvent.fromJson(item),
      ],
    );
  }
}

/// Day vs week schedule scope for the Planner date navigation.
enum ScheduleScope { day, week }

extension ScheduleScopeX on ScheduleScope {
  int get days => this == ScheduleScope.day ? 1 : 7;
  String get label => this == ScheduleScope.day ? 'Day' : 'Week';
}
