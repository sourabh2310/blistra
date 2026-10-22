/// Per-habit streaks, recent completion days and schedules for the Habits
/// pages, loaded lazily in the background so lists never wait on them.
///
/// Every value comes from the backend ([HabitsController.fetchStatistics],
/// [HabitsApi.fetchCompletions], [HabitsApi.getSchedule]). A failed fetch
/// leaves that habit without the extra detail; the page keeps working.
library;

import 'package:flutter/material.dart';

import 'habits_controller.dart';
import 'models.dart';

/// Local calendar day for [value] (completions arrive as UTC instants of a
/// local date).
DateTime habitDay(DateTime value) {
  final DateTime local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime habitToday() => habitDay(DateTime.now());

const List<String> kHabitWeekdays = [
  'MONDAY',
  'TUESDAY',
  'WEDNESDAY',
  'THURSDAY',
  'FRIDAY',
  'SATURDAY',
  'SUNDAY',
];

String _titleCase(String day) =>
    day.isEmpty ? day : day[0] + day.substring(1, 3).toLowerCase();

/// Whether [schedule] makes the habit due on [day].
bool isHabitDueOn(Schedule schedule, DateTime day) {
  if (schedule.frequency == HabitFrequency.daily) return true;
  return schedule.daysOfWeek
      .map((String d) => d.toUpperCase())
      .contains(kHabitWeekdays[day.weekday - 1]);
}

/// "Daily" or "Mon, Wed, Fri".
String scheduleLabel(Schedule schedule) {
  if (schedule.frequency == HabitFrequency.daily) return 'Daily';
  final List<String> days = [
    for (final String d in kHabitWeekdays)
      if (schedule.daysOfWeek.map((String x) => x.toUpperCase()).contains(d))
        _titleCase(d),
  ];
  return days.isEmpty ? 'Weekly' : days.join(', ');
}

String habitTypeLabel(HabitType type) => switch (type) {
      HabitType.boolean => 'Yes / no',
      HabitType.count => 'Count',
      HabitType.duration => 'Duration',
    };

IconData habitTypeIcon(HabitType type) => switch (type) {
      HabitType.boolean => Icons.check_circle_outline_rounded,
      HabitType.count => Icons.format_list_numbered_rounded,
      HabitType.duration => Icons.timer_outlined,
    };

String habitStatusLabel(HabitStatus status) => switch (status) {
      HabitStatus.active => 'Active',
      HabitStatus.paused => 'Paused',
      HabitStatus.archived => 'Archived',
    };

/// "8 glasses" / "20 min", or null when the habit has no target.
String? habitTargetLabel({
  required String? targetValue,
  required String? targetUnit,
  required int? targetMinutes,
}) {
  if (targetValue != null) {
    final String unit = targetUnit?.trim() ?? '';
    return unit.isEmpty ? targetValue : '$targetValue $unit';
  }
  if (targetMinutes != null) return '$targetMinutes min';
  return null;
}

String pluralDays(int n) => n == 1 ? '1 day' : '$n days';

/// "🔥 4 days · best 12" from real statistics.
String streakLabel(HabitStatisticsResponse stats) {
  final int current = stats.currentStreak;
  final int best = stats.bestStreak;
  if (current > 0 && current >= best) {
    return '🔥 ${pluralDays(current)} · best';
  }
  return '🔥 ${pluralDays(current)} · best $best';
}

/// Records or removes today's completion for [habit] and confirms it with a
/// snackbar. Returns true on success.
Future<bool> toggleTodayCompletion(
  BuildContext context,
  HabitsController controller,
  HabitTodayResponse habit,
  bool nowCompleted,
) async {
  final ScaffoldMessengerState? messenger =
      ScaffoldMessenger.maybeOf(context);
  // User-local calendar day: the backend compares against the user
  // timezone's today, so a UTC conversion here would record completions
  // on the wrong day around midnight.
  final DateTime today = DateTime.now();
  try {
    if (!nowCompleted) {
      // switched off - remove today's completion
      await controller.removeCompletion(habit.id, today);
    } else {
      // switched on - record a completion
      await controller.recordCompletion(
        habit.id,
        completedOn: today,
        value: habit.type == HabitType.count ? '1' : null,
        durationMinutes:
            habit.type == HabitType.duration ? habit.targetMinutes : null,
      );
    }
    messenger?.showSnackBar(
      SnackBar(
        content: Text(nowCompleted ? 'Marked complete' : 'Completion removed'),
        duration: const Duration(seconds: 1),
      ),
    );
    return true;
  } catch (error) {
    messenger?.showSnackBar(
      SnackBar(content: Text('Error: $error')),
    );
    return false;
  }
}

/// Completion rate and per-day ratios for the current Monday-to-Sunday week.
class HabitWeek {
  const HabitWeek({required this.days, required this.due, required this.done});

  /// Seven entries, Monday first: done/due for that day, or null when nothing
  /// was due (or the day is still ahead).
  final List<double?> days;
  final int due;
  final int done;

  double? get rate => due == 0 ? null : done / due;
}

class HabitInsights extends ChangeNotifier {
  HabitInsights(this.controller);

  final HabitsController controller;

  /// Completions fetched per habit: two weeks covers both the 7-dot history
  /// and the current week (one completion per habit per day).
  static const int _completionWindow = 14;

  final Map<String, HabitStatisticsResponse> _stats = {};
  final Map<String, Set<DateTime>> _days = {};
  final Map<String, Schedule?> _schedules = {};
  final Set<String> _statsRequested = {};
  final Set<String> _daysRequested = {};
  final Set<String> _scheduleRequested = {};
  final Set<String> _statsFailed = {};
  int _generation = 0;
  bool _disposed = false;

  HabitStatisticsResponse? statsFor(String id) => _stats[id];
  bool statsFailed(String id) => _statsFailed.contains(id);

  /// Local days with a completion in the recent window, or null until loaded.
  Set<DateTime>? daysFor(String id) => _days[id];

  /// Longest current streak among the loaded habits, or null if none loaded.
  int? get longestStreak {
    if (_stats.isEmpty) return null;
    return _stats.values
        .map((HabitStatisticsResponse s) => s.currentStreak)
        .reduce((int a, int b) => a > b ? a : b);
  }

  /// Starts any missing fetches for today's habits and the active habits.
  void ensure() {
    for (final HabitTodayResponse h in controller.todayHabits) {
      _ensureStats(h.id);
      _ensureDays(h.id);
      if (h.schedule != null) _schedules[h.id] = h.schedule;
    }
    for (final Habit h in controller.activeHabits) {
      _ensureDays(h.id);
      if (!_schedules.containsKey(h.id)) _ensureSchedule(h.id);
    }
  }

  /// Re-fetches one habit after its completions changed.
  void refresh(String id) {
    _statsRequested.remove(id);
    _daysRequested.remove(id);
    _statsFailed.remove(id);
    _ensureStats(id);
    _ensureDays(id);
  }

  /// Drops everything (e.g. after a full reload) and fetches again.
  void reset() {
    _generation++;
    _stats.clear();
    _days.clear();
    _schedules.clear();
    _statsRequested.clear();
    _daysRequested.clear();
    _scheduleRequested.clear();
    _statsFailed.clear();
    ensure();
    _notify();
  }

  /// This week's completion rate from loaded completions and schedules.
  /// Habits whose completions or schedule have not loaded are left out.
  HabitWeek week() {
    final DateTime today = habitToday();
    final DateTime monday = today.subtract(Duration(days: today.weekday - 1));
    final Map<String, Habit> active = {
      for (final Habit h in controller.activeHabits) h.id: h,
    };
    final List<double?> days = [];
    int due = 0;
    int done = 0;
    for (int i = 0; i < 7; i++) {
      final DateTime day = DateTime(monday.year, monday.month, monday.day + i);
      if (day.isAfter(today)) {
        days.add(null);
        continue;
      }
      int dayDue = 0;
      int dayDone = 0;
      for (final Habit habit in active.values) {
        final Schedule? schedule = _schedules[habit.id];
        final Set<DateTime>? completed = _days[habit.id];
        if (schedule == null || completed == null) continue;
        if (habitDay(habit.createdAt).isAfter(day)) continue;
        if (!isHabitDueOn(schedule, day)) continue;
        dayDue++;
        if (completed.contains(day)) dayDone++;
      }
      due += dayDue;
      done += dayDone;
      days.add(dayDue == 0 ? null : dayDone / dayDue);
    }
    return HabitWeek(days: days, due: due, done: done);
  }

  void _ensureStats(String id) {
    if (!_statsRequested.add(id)) return;
    final int gen = _generation;
    controller.fetchStatistics(id).then((HabitStatisticsResponse stats) {
      if (gen != _generation) return;
      _stats[id] = stats;
      _statsFailed.remove(id);
      _notify();
    }).catchError((Object _) {
      if (gen != _generation) return;
      _statsFailed.add(id);
      _notify();
    });
  }

  void _ensureDays(String id) {
    if (!_daysRequested.add(id)) return;
    final int gen = _generation;
    controller.api
        .fetchCompletions(id, size: _completionWindow)
        .then((PageResult<Completion> page) {
      if (gen != _generation) return;
      _days[id] = {
        for (final Completion c in page.items) habitDay(c.completedOn),
      };
      _notify();
    }).catchError((Object _) {
      // No history dots for this habit; nothing else depends on it.
    });
  }

  void _ensureSchedule(String id) {
    if (!_scheduleRequested.add(id)) return;
    final int gen = _generation;
    controller.api.getSchedule(id).then((Schedule schedule) {
      if (gen != _generation) return;
      _schedules[id] = schedule;
      _notify();
    }).catchError((Object _) {
      // No schedule: the habit is never due, so it stays out of the week.
    });
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
