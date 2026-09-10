/// Task priorities, mirroring the backend planner domain enums.
enum TaskPriority {
  low,
  medium,
  high;

  static TaskPriority fromWire(String? value) {
    switch (value?.toUpperCase()) {
      case 'LOW':
        return TaskPriority.low;
      case 'HIGH':
        return TaskPriority.high;
      default:
        return TaskPriority.medium;
    }
  }

  String get wireName => switch (this) {
        TaskPriority.low => 'LOW',
        TaskPriority.medium => 'MEDIUM',
        TaskPriority.high => 'HIGH',
      };
}