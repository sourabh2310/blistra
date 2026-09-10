import 'task_priority.dart';
import 'task_status.dart';

/// A planner task as returned by the backend. Field names mirror the
/// {@code TaskResponse} contract.
class PlannerTask {
  PlannerTask({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.overdue,
    this.description,
    this.dueDate,
    this.dueTime,
    this.dueAt,
    this.completedAt,
    this.taskListId,
    this.taskListName,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final TaskPriority priority;

  /// Calendar day in the user's timezone (date-only: YYYY-MM-DD).
  final DateTime? dueDate;

  /// Wall-clock time in the user's timezone (stored as a DateTime whose date
  /// part is arbitrary and must be ignored; format with {@code HH:mm}).
  final DateTime? dueTime;

  /// Resolved due instant (offset aware).
  final DateTime? dueAt;
  final DateTime? completedAt;
  final String? taskListId;
  final String? taskListName;
  final bool overdue;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PlannerTask.fromJson(Map<String, dynamic> json) {
    final dueDateRaw = json['dueDate'];
    final dueTimeRaw = json['dueTime'];
    final dueAtRaw = json['dueAt'];
    final completedRaw = json['completedAt'];
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];

    return PlannerTask(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: TaskStatus.fromWire(json['status'] as String?),
      priority: TaskPriority.fromWire(json['priority'] as String?),
      dueDate: dueDateRaw is String ? DateTime.parse(dueDateRaw) : null,
      dueTime: dueTimeRaw is String ? _parseTime(dueTimeRaw) : null,
      dueAt: dueAtRaw is String ? DateTime.parse(dueAtRaw) : null,
      completedAt: completedRaw is String ? DateTime.parse(completedRaw) : null,
      taskListId: json['taskListId'] as String?,
      taskListName: json['taskListName'] as String?,
      overdue: json['overdue'] == true,
      createdAt: createdAtRaw is String ? DateTime.parse(createdAtRaw) : null,
      updatedAt: updatedAtRaw is String ? DateTime.parse(updatedAtRaw) : null,
    );
  }

  /// Parses a bare wall-clock time like "09:30" or "09:30:00". The resulting
  /// DateTime's year/month/day are synthetic.
  static DateTime? _parseTime(String raw) {
    final first = raw.split(':').first;
    final hour = int.tryParse(first);
    final second = raw.contains(':') ? raw.split(':').elementAt(1) : null;
    final minute = int.tryParse(second ?? '0');
    if (hour == null || minute == null) {
      return null;
    }
    return DateTime(2000, 1, 1, hour, minute);
  }
}