/// Pure, testable helpers for the Planner Today experience.
///
/// All functions operate on plain data so they can be unit-tested without
/// widgets. The UI layer ([TodayScreen]) maps real Planner/Dashboard models
/// onto [TimelineEntry] and delegates summary/sectioning here.
library;

/// One chronological row on the Today timeline.
class TimelineEntry {
  TimelineEntry({
    required this.at,
    required this.title,
    required this.source,
    required this.done,
    this.cancelled = false,
  });

  final DateTime at;
  final String title;
  final String source;
  final bool done;
  final bool cancelled;
}

/// Factual completion totals derived from real items. Never a score.
class TodaySummary {
  TodaySummary({
    required this.total,
    required this.completed,
  });

  final int total;
  final int completed;

  int get remaining => total - completed;

  double get fraction => total == 0 ? 0 : completed / total;

  String get label {
    if (total == 0) return 'No plans yet';
    if (remaining == 0) return 'All done';
    return '$remaining of $total remaining';
  }
}

/// Computes factual totals from the visible timeline entries.
TodaySummary computeTodaySummary(List<TimelineEntry> entries) {
  final visible = entries.where((e) => !e.cancelled).toList();
  final completed = visible.where((e) => e.done).length;
  return TodaySummary(total: visible.length, completed: completed);
}

/// Sections for the Day timeline. Only non-empty sections are rendered.
class TodaySections {
  TodaySections({
    required this.overdue,
    required this.upNext,
    required this.laterToday,
    required this.completed,
  });

  final List<TimelineEntry> overdue;
  final List<TimelineEntry> upNext;
  final List<TimelineEntry> laterToday;
  final List<TimelineEntry> completed;
}

/// Splits [entries] (already sorted ascending) into Overdue / Up next /
/// Later today / Completed using the device-local clock.
///
/// - Cancelled entries are excluded entirely.
/// - Done entries go to [TodaySections.completed].
/// - Non-done entries with [at] before [now] go to overdue.
/// - The first upcoming non-done entry (and any within the same hour)
///   goes to up-next; the rest go to later-today.
TodaySections sectionEntries(List<TimelineEntry> entries, DateTime now) {
  final overdue = <TimelineEntry>[];
  final upcoming = <TimelineEntry>[];
  final completed = <TimelineEntry>[];
  for (final e in entries) {
    if (e.cancelled) continue;
    if (e.done) {
      completed.add(e);
      continue;
    }
    if (e.at.isBefore(now)) {
      overdue.add(e);
    } else {
      upcoming.add(e);
    }
  }
  final upNext = <TimelineEntry>[];
  final laterToday = <TimelineEntry>[];
  if (upcoming.isNotEmpty) {
    upNext.add(upcoming.first);
    for (final e in upcoming.skip(1)) {
      if (e.at.difference(upcoming.first.at).inMinutes <= 60) {
        upNext.add(e);
      } else {
        laterToday.add(e);
      }
    }
  }
  return TodaySections(
    overdue: overdue,
    upNext: upNext,
    laterToday: laterToday,
    completed: completed,
  );
}

/// Groups entries by local calendar day for the week overview.
Map<DateTime, int> countByDay(List<TimelineEntry> entries) {
  final counts = <DateTime, int>{};
  for (final e in entries) {
    if (e.cancelled) continue;
    final day = DateTime(e.at.year, e.at.month, e.at.day);
    counts[day] = (counts[day] ?? 0) + 1;
  }
  return counts;
}
