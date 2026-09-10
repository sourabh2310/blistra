/// Task collection lenses, mirroring the backend {@code TaskView} enum.
enum TaskView {
  all,
  active,
  completed,
  today,
  overdue,
  upcoming;

  static TaskView fromWire(String? value) {
    switch (value?.toUpperCase()) {
      case 'ACTIVE':
        return TaskView.active;
      case 'COMPLETED':
        return TaskView.completed;
      case 'TODAY':
        return TaskView.today;
      case 'OVERDUE':
        return TaskView.overdue;
      case 'UPCOMING':
        return TaskView.upcoming;
      default:
        return TaskView.all;
    }
  }

  String get wireName => name.toUpperCase();
}