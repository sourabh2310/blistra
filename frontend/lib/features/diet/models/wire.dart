/// Formats a [DateTime] the way Jackson's `OffsetDateTime` expects it:
/// an ISO-8601 timestamp carrying an explicit UTC offset.
///
/// `DateTime.toIso8601String()` drops the offset for local times, so it is not
/// safe for the wire.
String isoWithOffset(DateTime dateTime) {
  if (dateTime.isUtc) {
    return dateTime.toIso8601String();
  }
  final offset = dateTime.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final hours = offset.inHours.abs().toString().padLeft(2, '0');
  final minutes =
      (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return '${dateTime.toIso8601String()}$sign$hours:$minutes';
}

/// Parses a numeric JSON value (int or double) as a [double].
double? toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}