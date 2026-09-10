/// Event lifecycle statuses, mirroring the backend planner domain enums.
enum EventStatus {
  scheduled,
  completed,
  cancelled;

  static EventStatus fromWire(String? value) {
    switch (value?.toUpperCase()) {
      case 'COMPLETED':
        return EventStatus.completed;
      case 'CANCELLED':
        return EventStatus.cancelled;
      default:
        return EventStatus.scheduled;
    }
  }

  String get wireName => switch (this) {
        EventStatus.scheduled => 'SCHEDULED',
        EventStatus.completed => 'COMPLETED',
        EventStatus.cancelled => 'CANCELLED',
      };
}