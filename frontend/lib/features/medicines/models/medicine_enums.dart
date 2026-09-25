/// Domain enums shared by the Medicines feature, mirroring the backend enums.
library;

enum MedicineStatus {
  active,
  paused,
  completed,
  archived;

  /// Backend contract: ACTIVE / PAUSED / COMPLETED / ARCHIVED.
  static MedicineStatus fromWire(Object? raw) {
    switch (raw) {
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
}

enum ScheduleType {
  daily,
  weekly,
  customDays,
  asNeeded;

  /// Backend contract: DAILY / WEEKLY / CUSTOM_DAYS / AS_NEEDED.
  static ScheduleType fromWire(Object? raw) {
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
}

enum DoseStatus {
  taken,
  missed,
  skipped;

  /// Backend contract: TAKEN / MISSED / SKIPPED.
  static DoseStatus fromWire(Object? raw) {
    switch (raw) {
      case 'MISSED':
        return DoseStatus.missed;
      case 'SKIPPED':
        return DoseStatus.skipped;
      default:
        return DoseStatus.taken;
    }
  }
}

extension ScheduleTypeWire on ScheduleType {
  /// Backend contract: DAILY / WEEKLY / CUSTOM_DAYS / AS_NEEDED.
  String get wire => switch (this) {
        ScheduleType.daily => 'DAILY',
        ScheduleType.weekly => 'WEEKLY',
        ScheduleType.customDays => 'CUSTOM_DAYS',
        ScheduleType.asNeeded => 'AS_NEEDED',
      };
}