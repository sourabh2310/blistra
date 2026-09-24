enum TaskReminderMode {
  none,
  atStart,
  atEnd,
  atStartAndEnd;

  static TaskReminderMode fromWire(String? value) {
    switch (value?.toUpperCase()) {
      case 'AT_START':
        return TaskReminderMode.atStart;
      case 'AT_END':
        return TaskReminderMode.atEnd;
      case 'AT_START_AND_END':
        return TaskReminderMode.atStartAndEnd;
      default:
        return TaskReminderMode.none;
    }
  }

  String get wireName => switch (this) {
        TaskReminderMode.none => 'NONE',
        TaskReminderMode.atStart => 'AT_START',
        TaskReminderMode.atEnd => 'AT_END',
        TaskReminderMode.atStartAndEnd => 'AT_START_AND_END',
      };

  String get label => switch (this) {
        TaskReminderMode.none => 'None',
        TaskReminderMode.atStart => 'At start',
        TaskReminderMode.atEnd => 'At end',
        TaskReminderMode.atStartAndEnd => 'At start & end',
      };
}
