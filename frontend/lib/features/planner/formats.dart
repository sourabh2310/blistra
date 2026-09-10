import 'models/planner_event.dart';
import 'models/task.dart';

/// Small date/time formatting helpers used across planner screens.
/// No intl dependency: hand-rolled two-digit formatting keeps the app lean.
class Formats {
  Formats._();

  static String twoDigits(int value) => value.toString().padLeft(2, '0');

  static String timeOfDay(DateTime? time) {
    if (time == null) {
      return '';
    }
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  static String date(DateTime? date) {
    if (date == null) {
      return '';
    }
    return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}';
  }

  static String dateTime(DateTime? value) {
    if (value == null) {
      return '';
    }
    return '${date(value)} ${timeOfDay(value.toLocal())}';
  }

  /// "Today", "Tomorrow", "Yesterday" or a plain date - computed against the
  /// device-local calendar which is the user's practical frame of reference.
  static String dayLabel(DateTime? value) {
    if (value == null) {
      return '';
    }
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    if (day == today) {
      return 'Today';
    }
    if (day == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    }
    if (day == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return date(value);
  }

  static String taskDueLabel(PlannerTask task) {
    if (task.dueDate == null) {
      return '';
    }
    final time = timeOfDay(task.dueTime);
    final day = dayLabel(task.dueDate);
    return time.isEmpty ? day : '$day at $time';
  }

  static String eventRangeLabel(PlannerEvent event) {
    final start = event.startAt.toLocal();
    final end = event.endAt.toLocal();
    final sameDay = start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) {
      return '${dayLabel(start)} · ${timeOfDay(start)} – ${timeOfDay(end)}';
    }
    return '${dateTime(start)} – ${dateTime(end)}';
  }
}