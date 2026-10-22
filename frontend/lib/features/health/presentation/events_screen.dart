import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'event_form_screen.dart';
import 'widgets.dart';

class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key, required this.repository});

  final HealthRepository repository;

  @override
  Widget build(BuildContext context) {
    return RecordListScreen<HealthEvent>(
      title: 'Health events',
      noun: 'event',
      emptyMessage: 'No events yet. Record a check-up, vaccination or test.',
      load: repository.loadEvents,
      delete: (event) => repository.deleteEvent(event.id),
      itemBuilder: _row,
      formBuilder: (context, edited) =>
          EventFormScreen(repository: repository, initial: edited),
    );
  }

  static HealthRow _row(BuildContext context, HealthEvent event) =>
      eventRow(BlistraColors.resolve(context), event, DateTime.now());
}

/// Row for a health event, shared with the Health home.
HealthRow eventRow(BlistraColors colors, HealthEvent event, DateTime now) {
  return HealthRow(
    icon: switch (event.type) {
      EventType.checkup => Icons.medical_services_outlined,
      EventType.vaccination => Icons.vaccines_outlined,
      EventType.medicalVisit => Icons.local_hospital_outlined,
      EventType.labTest => Icons.science_outlined,
      EventType.other => Icons.event_note_outlined,
    },
    color: colors.data[0],
    title: event.title,
    subtitle: [
      eventTypeLabels[event.type] ?? event.type.wire,
      relativeDay(event.occurredAt, now),
    ].join(' · '),
  );
}
