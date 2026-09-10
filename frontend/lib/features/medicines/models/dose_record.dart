import 'medicine_enums.dart';

class DoseRecord {
  const DoseRecord({
    required this.id,
    required this.medicineId,
    this.scheduleId,
    required this.status,
    required this.scheduledAt,
    this.takenAt,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String medicineId;
  final String? scheduleId;
  final DoseStatus status;
  final DateTime scheduledAt;
  final DateTime? takenAt;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory DoseRecord.fromJson(Map<String, dynamic> json) => DoseRecord(
        id: json['id'] as String,
        medicineId: json['medicineId'] as String,
        scheduleId: json['scheduleId'] as String?,
        status: _statusFrom(json['status']),
        scheduledAt: _dateTimeFrom(json['scheduledAt']) ?? DateTime.now(),
        takenAt: _dateTimeFrom(json['takenAt']),
        note: json['note'] as String?,
        createdAt: _dateTimeFrom(json['createdAt']),
        updatedAt: _dateTimeFrom(json['updatedAt']),
      );

  static DoseStatus _statusFrom(Object? raw) {
    switch (raw) {
      case 'TAKEN':
        return DoseStatus.taken;
      case 'MISSED':
        return DoseStatus.missed;
      case 'SKIPPED':
        return DoseStatus.skipped;
      default:
        return DoseStatus.taken;
    }
  }

  static DateTime? _dateTimeFrom(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }
}

String doseStatusLabel(DoseStatus status) {
  switch (status) {
    case DoseStatus.taken:
      return 'Taken';
    case DoseStatus.missed:
      return 'Missed';
    case DoseStatus.skipped:
      return 'Skipped';
  }
}