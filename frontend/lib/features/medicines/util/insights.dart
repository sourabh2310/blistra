/// Derived figures for the Medicines pages, computed only from what the API
/// returns (schedules, dose records, refills, today's slots).
library;

import 'package:intl/intl.dart';

import '../models/dose_record.dart';
import '../models/medicine_enums.dart';
import '../models/refill.dart';
import '../models/schedule.dart';
import '../models/today_doses.dart';

/// Taken share of the recorded doses scheduled within the last [days] days,
/// or null when nothing was recorded in that window.
double? adherenceOver(Iterable<DoseRecord> doses, {int days = 7, DateTime? now}) {
  final DateTime end = now ?? DateTime.now();
  final DateTime start = DateTime(end.year, end.month, end.day)
      .subtract(Duration(days: days - 1));
  var total = 0;
  var taken = 0;
  for (final d in doses) {
    if (d.scheduledAt.isBefore(start) || d.scheduledAt.isAfter(end)) continue;
    total++;
    if (d.status == DoseStatus.taken) taken++;
  }
  return total == 0 ? null : taken / total;
}

/// Taken share of [doses], or null when empty.
double? adherenceOf(Iterable<DoseRecord> doses) {
  if (doses.isEmpty) return null;
  return doses.where((d) => d.status == DoseStatus.taken).length / doses.length;
}

/// Number of most recent doses recorded as taken in a row.
int takenStreak(Iterable<DoseRecord> doses) {
  final sorted = doses.toList()
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));
  var streak = 0;
  for (final d in sorted) {
    if (d.status != DoseStatus.taken) break;
    streak++;
  }
  return streak;
}

/// The most recent refill by date, or null.
Refill? latestRefill(Iterable<Refill> refills) {
  Refill? latest;
  for (final r in refills) {
    if (latest == null || r.refillDate.isAfter(latest.refillDate)) latest = r;
  }
  return latest;
}

/// A refill is low when its recorded remaining quantity is a quarter or less
/// of what was bought. Refills without a remaining quantity are never low.
bool isLowStock(Refill? refill) {
  final double? left = refill?.remainingQuantity;
  if (refill == null || left == null) return false;
  return left <= 0 || left <= refill.quantity * 0.25;
}

/// "Twice daily", "Weekly · Mon, Thu", "As needed"; "" with no active
/// schedules.
String scheduleSummary(Iterable<Schedule> schedules) {
  final parts = <String>[
    for (final s in schedules.where((s) => s.active)) _summaryOf(s),
  ];
  return parts.toSet().join(' + ');
}

String _summaryOf(Schedule s) {
  final n = s.times.length;
  final freq = switch (n) {
    1 => 'Once',
    2 => 'Twice',
    _ => '$n×',
  };
  return switch (s.scheduleType) {
    ScheduleType.daily => n == 0 ? 'Daily' : '$freq daily',
    ScheduleType.weekly || ScheduleType.customDays =>
      (s.daysOfWeek == null || s.daysOfWeek!.isEmpty)
          ? scheduleTypeLabel(s.scheduleType)
          : '${n > 1 ? '$freq · ' : ''}${s.daysOfWeek!.map(dayShort).join(', ')}',
    ScheduleType.asNeeded => 'As needed',
  };
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// "Mon" for 1 (Monday) through "Sun" for 7.
String dayShort(int index) =>
    index >= 1 && index <= 7 ? _days[index - 1] : '?';

/// "08:00" (wire) -> "8:00 AM"; unparseable text is returned unchanged.
String timeLabel(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return hhmm;
  return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
}

/// Part of the day a dose falls in, in display order.
enum DayPart {
  morning('Morning'),
  afternoon('Afternoon'),
  evening('Evening'),
  night('Night');

  const DayPart(this.label);
  final String label;

  static DayPart of(int hour) {
    if (hour >= 5 && hour < 12) return DayPart.morning;
    if (hour >= 12 && hour < 17) return DayPart.afternoon;
    if (hour >= 17 && hour < 21) return DayPart.evening;
    return DayPart.night;
  }
}

/// Today's doses grouped by [DayPart], each group in time order. Night holds
/// both late-evening and early-morning slots, so early slots sort first.
Map<DayPart, List<ExpectedDose>> groupByDayPart(Iterable<ExpectedDose> doses) {
  final groups = <DayPart, List<ExpectedDose>>{};
  for (final d in doses) {
    groups.putIfAbsent(DayPart.of(d.scheduledAt.hour), () => []).add(d);
  }
  for (final list in groups.values) {
    list.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  }
  return {
    for (final part in DayPart.values) part: ?groups[part],
  };
}

/// "Today 1:12 PM", "Yesterday 9:05 PM", "Mon 9:00 PM", "3 Sep 9:00 PM".
String relativeDateTime(DateTime at, {DateTime? now}) {
  final DateTime n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(at.year, at.month, at.day);
  final time = DateFormat('h:mm a').format(at);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today $time';
  if (diff == 1) return 'Yesterday $time';
  if (diff > 1 && diff < 7) return '${DateFormat('EEE').format(at)} $time';
  return '${DateFormat('d MMM').format(at)} $time';
}

/// "in 25 min", "in 2 h".
String dueIn(DateTime at, {DateTime? now}) {
  final minutes = at.difference(now ?? DateTime.now()).inMinutes;
  if (minutes < 60) return 'in ${minutes.clamp(1, 59)} min';
  return 'in ${(minutes / 60).round()} h';
}
