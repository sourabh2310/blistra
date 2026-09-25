/// Pure, widget-free helpers for the Health overview home screen.
///
/// All functions derive exclusively from the authenticated user's loaded
/// measurement records. They never invent values: empty inputs yield empty
/// outputs, and trend text is plain arithmetic (no medical interpretation).
library;

import 'health_models.dart';
import 'presentation/widgets.dart' show formatDouble;

/// Measurement types the backend supports, in overview display order.
const List<MeasurementType> overviewTypes = [
  MeasurementType.weight,
  MeasurementType.heartRate,
  MeasurementType.bloodPressure,
  MeasurementType.temperature,
  MeasurementType.height,
];

bool isSameLocalDay(DateTime a, DateTime b) {
  final DateTime x = a.toLocal();
  final DateTime y = b.toLocal();
  return x.year == y.year && x.month == y.month && x.day == y.day;
}

/// Newest record per type (by [HealthMeasurement.measuredAt] descending).
Map<MeasurementType, HealthMeasurement> latestPerType(
    List<HealthMeasurement> measurements) {
  final Map<MeasurementType, HealthMeasurement> latest = {};
  final List<HealthMeasurement> sorted = List.of(measurements)
    ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  for (final HealthMeasurement m in sorted) {
    latest.putIfAbsent(m.type, () => m);
  }
  return latest;
}

/// Records measured on [now]'s local calendar day, newest first.
List<HealthMeasurement> todayOnly(
    List<HealthMeasurement> measurements, DateTime now) {
  final List<HealthMeasurement> today = measurements
      .where((m) => isSameLocalDay(m.measuredAt, now))
      .toList()
    ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  return today;
}

/// History for one type, newest first, capped at [limit].
List<HealthMeasurement> historyFor(
  List<HealthMeasurement> measurements,
  MeasurementType type, {
  int limit = 10,
}) {
  final List<HealthMeasurement> history = measurements
      .where((m) => m.type == type)
      .toList()
    ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  return history.length <= limit ? history : history.sublist(0, limit);
}

/// Most recent [count] records across all types, newest first.
List<HealthMeasurement> mostRecent(
  List<HealthMeasurement> measurements, {
  int count = 5,
}) {
  final List<HealthMeasurement> sorted = List.of(measurements)
    ..sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
  return sorted.length <= count ? sorted : sorted.sublist(0, count);
}

/// Renders `72.4 KG` / `120 / 80 MMHG` (raw backend unit casing preserved).
String formatValue(HealthMeasurement m) {
  if (m.type == MeasurementType.bloodPressure &&
      m.valueDiastolic != null) {
    return '${formatDouble(m.value)} / ${formatDouble(m.valueDiastolic)} ${m.unit}';
  }
  final String unit = m.unit.isEmpty ? '' : ' ${m.unit}';
  return '${formatDouble(m.value)}$unit';
}

/// Plain-arithmetic change between the two newest records, e.g. `-0.7 KG`
/// or `+2 / -1 MMHG`. Returns null when a delta cannot be computed.
/// No medical interpretation is attached to the result.
String? deltaText(HealthMeasurement latest, HealthMeasurement? previous) {
  if (previous == null) {
    return null;
  }
  if (latest.type == MeasurementType.bloodPressure &&
      latest.valueDiastolic != null &&
      previous.valueDiastolic != null) {
    final double sys = _round1(latest.value - previous.value);
    final double dia =
        _round1(latest.valueDiastolic! - previous.valueDiastolic!);
    if (sys == 0 && dia == 0) {
      return 'No change since last reading';
    }
    return '${_signed(sys)} / ${_signed(dia)} ${latest.unit} vs last reading';
  }
  final double diff = _round1(latest.value - previous.value);
  if (diff == 0) {
    return 'No change since last reading';
  }
  final String unit = latest.unit.isEmpty ? '' : ' ${latest.unit}';
  return '${_signed(diff)}$unit vs last reading';
}

double _round1(double v) => (v * 10).round() / 10;

String _signed(double v) {
  final String body = formatDouble(v);
  if (v > 0) {
    return '+$body';
  }
  return body;
}
