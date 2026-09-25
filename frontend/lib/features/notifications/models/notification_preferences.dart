import 'reminder_type.dart';

/// Per-user delivery preferences backed by `/api/v1/notifications/preferences`.
///
/// Toggles are per category plus a global kill switch and a
/// `hide_sensitive_content` flag that keeps domain reminder content generic on
/// lock screens.
class NotificationPreferences {
  NotificationPreferences({
    required this.enabled,
    required this.medicineEnabled,
    required this.habitEnabled,
    required this.plannerEnabled,
    required this.healthEnabled,
    required this.generalEnabled,
    required this.hideSensitiveContent,
  });

  final bool enabled;
  final bool medicineEnabled;
  final bool habitEnabled;
  final bool plannerEnabled;
  final bool healthEnabled;
  final bool generalEnabled;
  final bool hideSensitiveContent;

  factory NotificationPreferences.defaults() => NotificationPreferences(
        enabled: true,
        medicineEnabled: true,
        habitEnabled: true,
        plannerEnabled: true,
        healthEnabled: true,
        generalEnabled: true,
        hideSensitiveContent: false,
      );

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? true,
      medicineEnabled: json['medicineEnabled'] as bool? ?? true,
      habitEnabled: json['habitEnabled'] as bool? ?? true,
      plannerEnabled: json['plannerEnabled'] as bool? ?? true,
      healthEnabled: json['healthEnabled'] as bool? ?? true,
      generalEnabled: json['generalEnabled'] as bool? ?? true,
      hideSensitiveContent: json['hideSensitiveContent'] as bool? ?? false,
    );
  }

  bool isEnabledFor(ReminderType type) {
    if (!enabled) return false;
    return switch (type) {
      ReminderType.medicine => medicineEnabled,
      ReminderType.habit => habitEnabled,
      ReminderType.planner => plannerEnabled,
      ReminderType.health => healthEnabled,
      ReminderType.general => generalEnabled,
    };
  }

  /// Whether content should be hidden for this reminder category.
  bool hidesContentFor(ReminderType type) =>
      hideSensitiveContent && type.isDomainType;

  NotificationPreferences copyWith({
    bool? enabled,
    bool? medicineEnabled,
    bool? habitEnabled,
    bool? plannerEnabled,
    bool? healthEnabled,
    bool? generalEnabled,
    bool? hideSensitiveContent,
  }) =>
      NotificationPreferences(
        enabled: enabled ?? this.enabled,
        medicineEnabled: medicineEnabled ?? this.medicineEnabled,
        habitEnabled: habitEnabled ?? this.habitEnabled,
        plannerEnabled: plannerEnabled ?? this.plannerEnabled,
        healthEnabled: healthEnabled ?? this.healthEnabled,
        generalEnabled: generalEnabled ?? this.generalEnabled,
        hideSensitiveContent: hideSensitiveContent ?? this.hideSensitiveContent,
      );
}