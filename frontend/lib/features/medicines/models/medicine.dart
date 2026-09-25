import 'package:intl/intl.dart';

import 'medicine_enums.dart';

class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    this.genericName,
    this.form,
    this.strength,
    this.strengthUnit,
    this.notes,
    required this.status,
    this.startDate,
    this.endDate,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? genericName;
  final String? form;
  final double? strength;
  final String? strengthUnit;
  final String? notes;
  final MedicineStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Medicine copyWith({
    String? name,
    String? genericName,
    String? form,
    double? strength,
    String? strengthUnit,
    String? notes,
    MedicineStatus? status,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Medicine(
      id: id,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      form: form ?? this.form,
      strength: strength ?? this.strength,
      strengthUnit: strengthUnit ?? this.strengthUnit,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        name: json['name'] as String,
        genericName: json['genericName'] as String?,
        form: json['form'] as String?,
        strength: (json['strength'] as num?)?.toDouble(),
        strengthUnit: json['strengthUnit'] as String?,
        notes: json['notes'] as String?,
        status: _statusFrom(json['status']),
        startDate: _dateFrom(json['startDate']),
        endDate: _dateFrom(json['endDate']),
        createdAt: _dateTimeFrom(json['createdAt']),
        updatedAt: _dateTimeFrom(json['updatedAt']),
      );

  String get strengthLabel {
    if (strength == null) {
      return '';
    }
    final String amount = _trimDecimal(strength!);
    final String unit = strengthUnit ?? '';
    return unit.isEmpty ? amount : '$amount $unit';
  }

  static String _trimDecimal(double value) =>
      value == value.roundToDouble()
          ? value.round().toString()
          : value.toString();

  static MedicineStatus _statusFrom(Object? raw) {
    switch (raw) {
      case 'ACTIVE':
        return MedicineStatus.active;
      case 'PAUSED':
        return MedicineStatus.paused;
      case 'COMPLETED':
        return MedicineStatus.completed;
      case 'ARCHIVED':
        return MedicineStatus.archived;
      default:
        return MedicineStatus.active;
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

String _datesKey(Medicine m) => '${m.id}:${m.updatedAt?.toIso8601String()}';

/// Human label for a medicine status.
String medicineStatusLabel(MedicineStatus status) {
  switch (status) {
    case MedicineStatus.active:
      return 'Active';
    case MedicineStatus.paused:
      return 'Paused';
    case MedicineStatus.completed:
      return 'Completed';
    case MedicineStatus.archived:
      return 'Archived';
  }
}

/// Short date label (e.g. "10 Sep 2026"), or "—" when absent.
String medicineStartDateLabel(Medicine m) {
  final DateTime? start = m.startDate;
  if (start == null) {
    return '—';
  }
  return DateFormat('dd MMM yyyy').format(start);
}

/// Equality key used to detect whether a medicine list has changed.
String medicineListKey(List<Medicine> medicines) =>
    medicines.map(_datesKey).join('|');