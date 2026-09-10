import 'reminder_type.dart';

/// A reminder as returned by the backend REST API.
///
/// `scheduledAt` is an absolute instant kept in UTC (ISO-8601 from the
/// backend's `TIMESTAMPTZ`). `timezone` is the user's IANA zone that was used
/// to choose the wall-clock time, which we keep for display only.
class Reminder {
  Reminder({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    required this.scheduledAt,
    required this.timezone,
    required this.status,
    this.sourceId,
  });

  final String id;
  final ReminderType type;
  final String title;
  final String? body;

  /// The absolute moment this reminder should fire, stored in UTC.
  final DateTime scheduledAt;

  /// IANA timezone id associated with the reminder (display purposes).
  final String timezone;
  final ReminderStatus status;

  /// Soft reference into the owning domain record for non-GENERAL reminders.
  final String? sourceId;

  bool get isActive => status == ReminderStatus.scheduled;

  bool get needsDelivery => isActive;

  factory Reminder.fromJson(Map<String, dynamic> json) {
    return Reminder(
      id: json['id'] as String,
      type: ReminderType.fromWire(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String?,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String).toUtc(),
      timezone: json['timezone'] as String,
      status: ReminderStatus.fromWire(json['status'] as String),
      sourceId: json['sourceId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.wire,
        'title': title,
        if (body != null) 'body': body,
        'scheduledAt': scheduledAt.toIso8601String(),
        'timezone': timezone,
        'status': status.wire,
        if (sourceId != null) 'sourceId': sourceId,
      };
}