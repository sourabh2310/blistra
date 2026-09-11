/// Domain enums shared by the Medicines feature, mirroring the backend enums.
library;

enum MedicineStatus { active, paused, completed, archived }

enum ScheduleType { daily, weekly, customDays, asNeeded }

enum DoseStatus { taken, missed, skipped }

extension ScheduleTypeWire on ScheduleType {
  /// Backend contract: DAILY / WEEKLY / CUSTOM_DAYS / AS_NEEDED.
  String get wire => switch (this) {
        ScheduleType.daily => 'DAILY',
        ScheduleType.weekly => 'WEEKLY',
        ScheduleType.customDays => 'CUSTOM_DAYS',
        ScheduleType.asNeeded => 'AS_NEEDED',
      };
}