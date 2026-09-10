import 'package:intl/intl.dart';

import '../util/dates.dart';
import 'medicine_enums.dart';

class Schedule {
  const Schedule({
    required this.id,
    required this.medicineId,
    required this.scheduleType,
    required this.times,
    this.daysOfWeek,
    this.doseAmount,
    this.doseUnit,
    this.startDate,
    this.endDate,
    required this.active,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String medicineId;
  final ScheduleType scheduleType;

  /// Time-of-day values as HH:mm strings (matches the backend wire format).
  final List<String> times;
  final List<int>? daysOfWeek;
  final double? doseAmount;
  final String? doseUnit;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Schedule.fromJson(Map<String, dynamic> json) => Schedule(
        id: json['id'] as String,
        medicineId: json['medicineId'] as String,
        scheduleType: _typeFrom(json['scheduleType']),
        times: ((json['times'] as List?) ?? const [])
            .whereType<String>()
            .toList(),
        daysOfWeek: (json['daysOfWeek'] as List?)?.map(_dayOfWeekToIndex).toList(),
        doseAmount: (json['doseAmount'] as num?)?.toDouble(),
        doseUnit: json['doseUnit'] as String?,
        startDate: _dateFrom(json['startDate']),
        endDate: _dateFrom(json['endDate']),
        active: json['active'] == true,
        createdAt: _dateTimeFrom(json['createdAt']),
        updatedAt: _dateTimeFrom(json['updatedAt']),
      );

  String get doseLabel {
    if (doseAmount == null) {
      return '';
    }
    final String amount = _trimDecimal(doseAmount!);
    final String unit = doseUnit ?? '';
    return unit.isEmpty ? amount : '$amount $unit';
  }

  static String _trimDecimal(double value) =>
      value == value.roundToDouble() ? value.round().toString() : value.toString();

  static ScheduleType _typeFrom(Object? raw) {
    switch (raw) {
      case 'WEEKLY':
        return ScheduleType.weekly;
      case 'CUSTOM_DAYS':
        return ScheduleType.customDays;
      case 'AS_NEEDED':
        return ScheduleType.asNeeded;
      default:
        return ScheduleType.daily;
    }
  }

  // The backend serializes Java DayOfWeek values; map wins to the 1-7 index
  // Flutter's DateTime.weekday uses (Monday == 1).
  static int _dayOfWeekToIndex(Object? raw) {
    switch (raw) {
      case 'MONDAY':
        return DateTime.monday;
      case 'TUESDAY':
        return DateTime.tuesday;
      case 'WEDNESDAY':
        return DateTime.wednesday;
      case 'THURSDAY':
        return DateTime.thursday;
      case 'FRIDAY':
        return DateTime.friday;
      case 'SATURDAY':
        return DateTime.saturday;
      case 'SUNDAY':
        return DateTime.sunday;
      default:
        return DateTime.monday;
    }
  }

  static DateTime? _dateFrom(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw);
  }

  static DateTime? _dateTimeFrom(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }
}

/// Human label for a schedule type.
String scheduleTypeLabel(ScheduleType type) {
  switch (type) {
    case ScheduleType.daily:
      return 'Daily';
    case ScheduleType.weekly:
      return 'Weekly';
    case ScheduleType.customDays:
      return 'Custom days';
    case ScheduleType.asNeeded:
      return 'As needed';
  }
}

/// Reads the active window into a short label, e.g. "10 Sep - 20 Sep".
String scheduleRangeLabel(Schedule s) {
  final DateTime? start = s.startDate;
  final DateTime? end = s.endDate;
  if (start == null && end == null) {
    return 'Unlimited';
  }
  final String f = DateFormat('dd MMM yyyy');
  if (start == null) {
    return 'until ${f.format(end!)}';
  }
  if (end == null) {
    return 'from ${f.format(start)}';
  }
  return '${f.format(start)} - ${f.format(end)}';
}