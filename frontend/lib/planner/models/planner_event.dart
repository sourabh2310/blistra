import 'event_status.dart';

/// A simple time-blocked planner event, mirroring {@code EventResponse}.
class PlannerEvent {
  PlannerEvent({
    required this.id,
    required this.title,
    required this.status,
    required this.startAt,
    required this.endAt,
    this.description,
    this.location,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? location;
  final DateTime startAt;
  final DateTime endAt;
  final EventStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory PlannerEvent.fromJson(Map<String, dynamic> json) {
    final startRaw = json['startAt'];
    final endRaw = json['endAt'];
    final createdAtRaw = json['createdAt'];
    final updatedAtRaw = json['updatedAt'];
    return PlannerEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startAt: DateTime.parse(startRaw as String),
      endAt: DateTime.parse(endRaw as String),
      status: EventStatus.fromWire(json['status'] as String?),
      createdAt: createdAtRaw is String ? DateTime.parse(createdAtRaw) : null,
      updatedAt: updatedAtRaw is String ? DateTime.parse(updatedAtRaw) : null,
    );
  }
}