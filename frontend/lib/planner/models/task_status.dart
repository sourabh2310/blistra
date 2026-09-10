/// Task lifecycle statuses, mirroring the backend planner domain enums.
enum TaskStatus {
  todo,
  inProgress,
  completed,
  cancelled;

  static TaskStatus fromWire(String? value) {
    switch (value?.toUpperCase()) {
      case 'IN_PROGRESS':
        return TaskStatus.inProgress;
      case 'COMPLETED':
        return TaskStatus.completed;
      case 'CANCELLED':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.todo;
    }
  }

  String get wireName => switch (this) {
        TaskStatus.todo => 'TODO',
        TaskStatus.inProgress => 'IN_PROGRESS',
        TaskStatus.completed => 'COMPLETED',
        TaskStatus.cancelled => 'CANCELLED',
      };

  bool get isActive =>
      this == TaskStatus.todo || this == TaskStatus.inProgress;
}