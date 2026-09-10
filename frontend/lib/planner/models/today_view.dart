import 'planner_event.dart';
import 'task.dart';

/// Planner "today" view, mirroring {@code TodayResponse}.
class TodayView {
  TodayView({
    required this.overdueTasks,
    required this.todayTasks,
    required this.todayEvents,
  });

  final List<PlannerTask> overdueTasks;
  final List<PlannerTask> todayTasks;
  final List<PlannerEvent> todayEvents;

  factory TodayView.fromJson(Map<String, dynamic> json) {
    return TodayView(
      overdueTasks: _tasks(json['overdueTasks']),
      todayTasks: _tasks(json['todayTasks']),
      todayEvents: _events(json['todayEvents']),
    );
  }

  static List<PlannerTask> _tasks(dynamic raw) => [
        if (raw is List)
          for (final item in raw)
            if (item is Map<String, dynamic>) PlannerTask.fromJson(item),
      ];

  static List<PlannerEvent> _events(dynamic raw) => [
        if (raw is List)
          for (final item in raw)
            if (item is Map<String, dynamic>) PlannerEvent.fromJson(item),
      ];
}