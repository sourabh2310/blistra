/// Wire-aligned reminder category. Mirrors the backend `ReminderType` enum:
/// `MEDICINE`, `HABIT`, `PLANNER`, `HEALTH`, `GENERAL`.
///
/// Only `general` reminders can be created by the client; the other categories
/// are owned by their respective domain modules on the backend.
enum ReminderType {
  medicine('MEDICINE'),
  habit('HABIT'),
  planner('PLANNER'),
  health('HEALTH'),
  general('GENERAL');

  const ReminderType(this.wire);

  final String wire;

  static ReminderType fromWire(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => general);

  bool get isDomainType => this != general;
}

/// Whether a reminder is still to be delivered.
enum ReminderStatus {
  scheduled('SCHEDULED'),
  cancelled('CANCELLED'),
  all('ALL');

  const ReminderStatus(this.wire);

  final String wire;

  static ReminderStatus fromWire(String value) =>
      values.firstWhere((e) => e.wire == value, orElse: () => scheduled);
}

/// Device platform used when registering for (future) push delivery.
enum DevicePlatform {
  android('ANDROID'),
  ios('IOS'),
  web('WEB');

  const DevicePlatform(this.wire);

  final String wire;
}