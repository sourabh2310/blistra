/// Date and time helpers for the wire formats used by the Medicines API.
library;

import 'package:intl/intl.dart';

/// Formats an optional local date as the bare ISO date (yyyy-MM-dd) the
/// backend uses for LocalDate fields, or null.
String? isoDateOrNull(DateTime? value) =>
    value == null ? null : DateFormat('yyyy-MM-dd').format(value);

/// Formats [time] as HH:mm (the backend LocalTime wire format).
String isoTime(DateTime time) => DateFormat('HH:mm').format(time);

/// Renders a local [DateTime] with its UTC offset appended so the backend can
/// parse it as an OffsetDateTime (for example 2026-09-10T14:30:00.000+05:30).
String toOffsetIso(DateTime value) {
  final Duration offset = value.timeZoneOffset;
  final String sign = offset.isNegative ? '-' : '+';
  final String hours = offset.abs().inHours.toString().padLeft(2, '0');
  final String minutes = (offset.abs().inMinutes % 60).toString().padLeft(2, '0');
  return '${value.toIso8601String()}$sign$hours:$minutes';
}

/// The current instant rendered as an OffsetDateTime string.
String nowOffsetIso() => toOffsetIso(DateTime.now());