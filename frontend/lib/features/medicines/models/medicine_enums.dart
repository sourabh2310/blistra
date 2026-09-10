/// Domain enums shared by the Medicines feature, mirroring the backend enums.
library;

enum MedicineStatus { active, paused, completed, archived }

enum ScheduleType { daily, weekly, customDays, asNeeded }

enum DoseStatus { taken, missed, skipped }