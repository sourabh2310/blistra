/// Typed Dart models that mirror the backend Health module DTOs.
///
/// Enums use explicit `wire` values (the backend serializes Java enum names
/// such as `HEART_RATE`, `BLOOD_PRESSURE`) instead of relying on Dart's
/// camelCase enum `.name`, so the mapping stays correct.
///
/// Wire timestamps are ISO-8601. `OffsetDateTime` fields (measuredAt,
/// observedAt, scheduledAt, ...) parse with `DateTime.parse`. When sending a
/// timestamp to the backend the value is always converted to UTC ISO-8601,
/// because the backend stores timestamps in UTC.
library;

T? _firstWhereOrNull<T>(Iterable<T> values, bool Function(T) test) {
  for (final T value in values) {
    if (test(value)) {
      return value;
    }
  }
  return null;
}

Map<String, dynamic> _asMap(Object? raw) => Map<String, dynamic>.from(raw as Map);

String? _string(Map<String, dynamic> json, String key) =>
    json[key] is String ? json[key] as String : null;

int? _int(Map<String, dynamic> json, String key) =>
    json[key] is num ? (json[key] as num).toInt() : null;

double? _double(Map<String, dynamic> json, String key) =>
    json[key] is num ? (json[key] as num).toDouble() : null;

DateTime? _dateTime(Map<String, dynamic> json, String key) {
  final String? raw = _string(json, key);
  return raw == null ? null : DateTime.tryParse(raw);
}

/// Formats a [DateTime] as `yyyy-MM-dd` for the backend's `LocalDate` fields
/// (e.g. `dateOfBirth`) and as full UTC ISO-8601 for `OffsetDateTime` fields.
// ignore: non_constant_identifier_names
String toWireDate(DateTime value) {
  final String y = value.year.toString().padLeft(4, '0');
  final String m = value.month.toString().padLeft(2, '0');
  final String d = value.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Converts the instant to a UTC ISO-8601 string, which the backend always
/// accepts for `OffsetDateTime` fields.
String toWireTimestamp(DateTime value) => value.toUtc().toIso8601String();

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum MeasurementType {
  weight,
  height,
  heartRate,
  temperature,
  bloodPressure;

  String get wire => switch (this) {
        MeasurementType.weight => 'WEIGHT',
        MeasurementType.height => 'HEIGHT',
        MeasurementType.heartRate => 'HEART_RATE',
        MeasurementType.temperature => 'TEMPERATURE',
        MeasurementType.bloodPressure => 'BLOOD_PRESSURE',
      };

  static MeasurementType? fromWire(Object? raw) => raw is String
      ? _firstWhereOrNull(MeasurementType.values, (e) => e.wire == raw)
      : null;
}

enum BloodType {
  aPositive,
  aNegative,
  bPositive,
  bNegative,
  abPositive,
  abNegative,
  oPositive,
  oNegative,
  unknown;

  String get wire => switch (this) {
        BloodType.aPositive => 'A_POSITIVE',
        BloodType.aNegative => 'A_NEGATIVE',
        BloodType.bPositive => 'B_POSITIVE',
        BloodType.bNegative => 'B_NEGATIVE',
        BloodType.abPositive => 'AB_POSITIVE',
        BloodType.abNegative => 'AB_NEGATIVE',
        BloodType.oPositive => 'O_POSITIVE',
        BloodType.oNegative => 'O_NEGATIVE',
        BloodType.unknown => 'UNKNOWN',
      };

  static BloodType? fromWire(Object? raw) => raw is String
      ? _firstWhereOrNull(BloodType.values, (e) => e.wire == raw)
      : null;
}

enum Severity {
  mild,
  moderate,
  severe;

  String get wire => switch (this) {
        Severity.mild => 'MILD',
        Severity.moderate => 'MODERATE',
        Severity.severe => 'SEVERE',
      };

  static Severity? fromWire(Object? raw) => raw is String
      ? _firstWhereOrNull(Severity.values, (e) => e.wire == raw)
      : null;
}

enum ActivityType {
  walking,
  running,
  cycling,
  swimming,
  strengthTraining,
  yoga,
  sports,
  other;

  String get wire => switch (this) {
        ActivityType.walking => 'WALKING',
        ActivityType.running => 'RUNNING',
        ActivityType.cycling => 'CYCLING',
        ActivityType.swimming => 'SWIMMING',
        ActivityType.strengthTraining => 'STRENGTH_TRAINING',
        ActivityType.yoga => 'YOGA',
        ActivityType.sports => 'SPORTS',
        ActivityType.other => 'OTHER',
      };

  static ActivityType? fromWire(Object? raw) => raw is String
      ? _firstWhereOrNull(ActivityType.values, (e) => e.wire == raw)
      : null;
}

enum EventType {
  checkup,
  vaccination,
  medicalVisit,
  labTest,
  other;

  String get wire => switch (this) {
        EventType.checkup => 'CHECKUP',
        EventType.vaccination => 'VACCINATION',
        EventType.medicalVisit => 'MEDICAL_VISIT',
        EventType.labTest => 'LAB_TEST',
        EventType.other => 'OTHER',
      };

  static EventType? fromWire(Object? raw) => raw is String
      ? _firstWhereOrNull(EventType.values, (e) => e.wire == raw)
      : null;
}

enum AppointmentStatus {
  scheduled,
  confirmed,
  completed,
  cancelled,
  missed;

  String get wire => switch (this) {
        AppointmentStatus.scheduled => 'SCHEDULED',
        AppointmentStatus.confirmed => 'CONFIRMED',
        AppointmentStatus.completed => 'COMPLETED',
        AppointmentStatus.cancelled => 'CANCELLED',
        AppointmentStatus.missed => 'MISSED',
      };

  static AppointmentStatus? fromWire(Object? raw) => raw is String
      ? _firstWhereOrNull(AppointmentStatus.values, (e) => e.wire == raw)
      : null;
}

// ---------------------------------------------------------------------------
// Response models
// ---------------------------------------------------------------------------

class HealthProfile {
  const HealthProfile({
    this.id,
    this.heightCm,
    this.bloodType,
    this.dateOfBirth,
    this.createdAt,
    this.updatedAt,
  });

  factory HealthProfile.fromJson(Map<String, dynamic> json) => HealthProfile(
        id: _string(json, 'id'),
        heightCm: _double(json, 'heightCm'),
        bloodType: BloodType.fromWire(json['bloodType']),
        dateOfBirth: _dateTime(json, 'dateOfBirth'),
        createdAt: _dateTime(json, 'createdAt'),
        updatedAt: _dateTime(json, 'updatedAt'),
      );

  final String? id;
  final double? heightCm;
  final BloodType? bloodType;
  final DateTime? dateOfBirth;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class HealthMeasurement {
  const HealthMeasurement({
    required this.id,
    required this.type,
    required this.measuredAt,
    required this.value,
    this.valueDiastolic,
    required this.unit,
    this.source,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory HealthMeasurement.fromJson(Map<String, dynamic> json) =>
      HealthMeasurement(
        id: json['id'] as String,
        type: MeasurementType.fromWire(json['type']) ?? MeasurementType.weight,
        measuredAt: _dateTime(json, 'measuredAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
        value: _double(json, 'value') ?? 0,
        valueDiastolic: _double(json, 'valueDiastolic'),
        unit: _string(json, 'unit') ?? '',
        source: _string(json, 'source'),
        notes: _string(json, 'notes'),
        createdAt: _dateTime(json, 'createdAt'),
        updatedAt: _dateTime(json, 'updatedAt'),
      );

  final String id;
  final MeasurementType type;
  final DateTime measuredAt;
  final double value;
  final double? valueDiastolic;
  final String unit;
  final String? source;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class HealthSleepRecord {
  const HealthSleepRecord({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    this.durationMinutes,
    this.rating,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory HealthSleepRecord.fromJson(Map<String, dynamic> json) =>
      HealthSleepRecord(
        id: json['id'] as String,
        startedAt:
            _dateTime(json, 'startedAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
        endedAt:
            _dateTime(json, 'endedAt') ?? DateTime.fromMillisecondsSinceEpoch(0),
        durationMinutes: _int(json, 'durationMinutes'),
        rating: _int(json, 'rating'),
        notes: _string(json, 'notes'),
        createdAt: _dateTime(json, 'createdAt'),
        updatedAt: _dateTime(json, 'updatedAt'),
      );

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final int? durationMinutes;
  final int? rating;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class HealthActivity {
  const HealthActivity({
    required this.id,
    required this.type,
    required this.performedAt,
    this.durationMinutes,
    this.distanceKm,
    this.caloriesBurned,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory HealthActivity.fromJson(Map<String, dynamic> json) => HealthActivity(
        id: json['id'] as String,
        type: ActivityType.fromWire(json['type']) ?? ActivityType.other,
        performedAt: _dateTime(json, 'performedAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        durationMinutes: _int(json, 'durationMinutes'),
        distanceKm: _double(json, 'distanceKm'),
        caloriesBurned: _int(json, 'caloriesBurned'),
        notes: _string(json, 'notes'),
        createdAt: _dateTime(json, 'createdAt'),
        updatedAt: _dateTime(json, 'updatedAt'),
      );

  final String id;
  final ActivityType type;
  final DateTime performedAt;
  final int? durationMinutes;
  final double? distanceKm;
  final int? caloriesBurned;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class HealthLogEntry {
  const HealthLogEntry({
    required this.id,
    this.title = '',
    this.description,
    required this.observedAt,
    this.severity,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory HealthLogEntry.fromJson(Map<String, dynamic> json) => HealthLogEntry(
        id: json['id'] as String,
        title: _string(json, 'title') ?? '',
        description: _string(json, 'description'),
        observedAt: _dateTime(json, 'observedAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        severity: Severity.fromWire(json['severity']),
        notes: _string(json, 'notes'),
        createdAt: _dateTime(json, 'createdAt'),
        updatedAt: _dateTime(json, 'updatedAt'),
      );

  final String id;
  final String title;
  final String? description;
  final DateTime observedAt;
  final Severity? severity;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class HealthEvent {
  const HealthEvent({
    required this.id,
    required this.type,
    this.title = '',
    required this.occurredAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory HealthEvent.fromJson(Map<String, dynamic> json) => HealthEvent(
        id: json['id'] as String,
        type: EventType.fromWire(json['type']) ?? EventType.other,
        title: _string(json, 'title') ?? '',
        occurredAt: _dateTime(json, 'occurredAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        notes: _string(json, 'notes'),
        createdAt: _dateTime(json, 'createdAt'),
        updatedAt: _dateTime(json, 'updatedAt'),
      );

  final String id;
  final EventType type;
  final String title;
  final DateTime occurredAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

class HealthAppointment {
  const HealthAppointment({
    required this.id,
    this.title = '',
    required this.scheduledAt,
    this.location,
    this.notes,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory HealthAppointment.fromJson(Map<String, dynamic> json) =>
      HealthAppointment(
        id: json['id'] as String,
        title: _string(json, 'title') ?? '',
        scheduledAt: _dateTime(json, 'scheduledAt') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        location: _string(json, 'location'),
        notes: _string(json, 'notes'),
        status: AppointmentStatus.fromWire(json['status']),
        createdAt: _dateTime(json, 'createdAt'),
        updatedAt: _dateTime(json, 'updatedAt'),
      );

  final String id;
  final String title;
  final DateTime scheduledAt;
  final String? location;
  final String? notes;
  final AppointmentStatus? status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// Mirrors the backend `PageResponse<T>` envelope used by every list endpoint.
class HealthPage<T> {
  const HealthPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  factory HealthPage.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) itemFromJson,
  ) {
    final List<dynamic> rawContent = json['content'] is List
        ? json['content'] as List
        : const [];
    return HealthPage<T>(
      content: rawContent
          .map((Object? element) => itemFromJson(_asMap(element)))
          .toList(),
      page: json['page'] is num ? (json['page'] as num).toInt() : 0,
      size: json['size'] is num ? (json['size'] as num).toInt() : 20,
      totalElements: json['totalElements'] is num
          ? (json['totalElements'] as num).toInt()
          : 0,
      totalPages:
          json['totalPages'] is num ? (json['totalPages'] as num).toInt() : 0,
      last: json['last'] is bool ? json['last'] as bool : true,
    );
  }

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
}

// ---------------------------------------------------------------------------
// Request inputs
// ---------------------------------------------------------------------------

class MeasurementInput {
  const MeasurementInput({
    required this.type,
    required this.measuredAt,
    required this.value,
    this.valueDiastolic,
    required this.unit,
    this.source,
    this.notes,
  });

  final MeasurementType type;
  final DateTime measuredAt;
  final double value;
  final double? valueDiastolic;
  final String unit;
  final String? source;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'measuredAt': toWireTimestamp(measuredAt),
        'value': value,
        if (valueDiastolic != null) 'valueDiastolic': valueDiastolic,
        'unit': unit,
        if (source != null && source!.isNotEmpty) 'source': source,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class SleepInput {
  const SleepInput({
    required this.startedAt,
    required this.endedAt,
    this.rating,
    this.notes,
  });

  final DateTime startedAt;
  final DateTime endedAt;
  final int? rating;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'startedAt': toWireTimestamp(startedAt),
        'endedAt': toWireTimestamp(endedAt),
        if (rating != null) 'rating': rating,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class ActivityInput {
  const ActivityInput({
    required this.type,
    required this.performedAt,
    this.durationMinutes,
    this.distanceKm,
    this.caloriesBurned,
    this.notes,
  });

  final ActivityType type;
  final DateTime performedAt;
  final int? durationMinutes;
  final double? distanceKm;
  final int? caloriesBurned;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'performedAt': toWireTimestamp(performedAt),
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (distanceKm != null) 'distanceKm': distanceKm,
        if (caloriesBurned != null) 'caloriesBurned': caloriesBurned,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class LogInput {
  const LogInput({
    this.title = '',
    this.description,
    required this.observedAt,
    this.severity,
    this.notes,
  });

  final String title;
  final String? description;
  final DateTime observedAt;
  final Severity? severity;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'title': title,
        if (description != null && description!.isNotEmpty)
          'description': description,
        'observedAt': toWireTimestamp(observedAt),
        if (severity != null) 'severity': severity!.wire,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class EventInput {
  const EventInput({
    required this.type,
    this.title = '',
    required this.occurredAt,
    this.notes,
  });

  final EventType type;
  final String title;
  final DateTime occurredAt;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'type': type.wire,
        'title': title,
        'occurredAt': toWireTimestamp(occurredAt),
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}

class AppointmentInput {
  const AppointmentInput({
    this.title = '',
    required this.scheduledAt,
    this.location,
    this.notes,
    this.status,
  });

  final String title;
  final DateTime scheduledAt;
  final String? location;
  final String? notes;
  final AppointmentStatus? status;

  Map<String, dynamic> toJson() => {
        'title': title,
        'scheduledAt': toWireTimestamp(scheduledAt),
        if (location != null && location!.isNotEmpty) 'location': location,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        if (status != null) 'status': status!.wire,
      };
}

class HealthProfileInput {
  const HealthProfileInput({
    required this.heightCm,
    required this.bloodType,
    required this.dateOfBirth,
  });

  final double? heightCm;
  final BloodType? bloodType;
  final DateTime? dateOfBirth;

  Map<String, dynamic> toJson() => {
        'heightCm': heightCm,
        'bloodType': bloodType?.wire,
        'dateOfBirth':
            dateOfBirth == null ? null : toWireDate(dateOfBirth!),
      };
}