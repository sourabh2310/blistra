/// Today view models mirroring the backend `MedicineTodayResponse`.
library;

import 'medicine_enums.dart';

/// One expected dose occurrence for the user's current local date.
///
/// A dose is pending until the user records it; [status] is null while
/// pending and the recorded [DoseStatus] otherwise.
class ExpectedDose {
  const ExpectedDose({
    required this.medicineId,
    required this.medicineName,
    this.scheduleId,
    required this.scheduledAt,
    this.status,
    this.takenAt,
    this.doseAmount,
    this.doseUnit,
    this.doseRecordId,
  });

  factory ExpectedDose.fromJson(Map<String, dynamic> json) {
    final Object? rawStatus = json['status'];
    return ExpectedDose(
      medicineId: json['medicineId'] as String,
      medicineName: json['medicineName'] as String? ?? '',
      scheduleId: json['scheduleId'] as String?,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String).toLocal(),
      status: rawStatus == 'PENDING' || rawStatus == null
          ? null
          : DoseStatus.fromWire(rawStatus),
      takenAt: json['takenAt'] is String
          ? DateTime.tryParse(json['takenAt'] as String)?.toLocal()
          : null,
      doseAmount: json['doseAmount'] as String?,
      doseUnit: json['doseUnit'] as String?,
      doseRecordId: json['doseRecordId'] as String?,
    );
  }

  final String medicineId;
  final String medicineName;
  final String? scheduleId;
  final DateTime scheduledAt;

  /// Null while the slot is unrecorded (pending).
  final DoseStatus? status;
  final DateTime? takenAt;
  final String? doseAmount;
  final String? doseUnit;
  final String? doseRecordId;

  bool get isPending => status == null;
  bool get isTaken => status == DoseStatus.taken;

  /// "500 mg", "1 tablet", or "" when the schedule declares no amount.
  String get doseLabel {
    final String amount = doseAmount ?? '';
    final String unit = doseUnit ?? '';
    if (amount.isEmpty && unit.isEmpty) {
      return '';
    }
    if (amount.isEmpty) {
      return unit;
    }
    if (unit.isEmpty) {
      return amount;
    }
    return '$amount $unit';
  }
}

class MedicineToday {
  const MedicineToday({
    required this.date,
    required this.totalDoses,
    required this.takenDoses,
    required this.remainingDoses,
    required this.missedDoses,
    required this.skippedDoses,
    this.nextDose,
    required this.doses,
  });

  factory MedicineToday.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['doses'] is List ? json['doses'] as List : const [];
    final Object? rawNext = json['nextDose'];
    return MedicineToday(
      date: DateTime.parse(json['date'] as String),
      totalDoses: (json['totalDoses'] as num?)?.toInt() ?? 0,
      takenDoses: (json['takenDoses'] as num?)?.toInt() ?? 0,
      remainingDoses: (json['remainingDoses'] as num?)?.toInt() ?? 0,
      missedDoses: (json['missedDoses'] as num?)?.toInt() ?? 0,
      skippedDoses: (json['skippedDoses'] as num?)?.toInt() ?? 0,
      nextDose: rawNext is Map<String, dynamic> ? ExpectedDose.fromJson(rawNext) : null,
      doses: raw.whereType<Map<String, dynamic>>().map(ExpectedDose.fromJson).toList(),
    );
  }

  factory MedicineToday.empty(DateTime date) => MedicineToday(
        date: date,
        totalDoses: 0,
        takenDoses: 0,
        remainingDoses: 0,
        missedDoses: 0,
        skippedDoses: 0,
        doses: const [],
      );

  final DateTime date;
  final int totalDoses;
  final int takenDoses;
  final int remainingDoses;
  final int missedDoses;
  final int skippedDoses;
  final ExpectedDose? nextDose;
  final List<ExpectedDose> doses;

  bool get isEmpty => totalDoses == 0;
  bool get allCompleted => totalDoses > 0 && remainingDoses == 0 && missedDoses == 0;
}
