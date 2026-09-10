import 'package:flutter/material.dart';

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
      emptyMessage: 'No events yet.\nTap + to record one.',
      load: repository.loadEvents,
      delete: (event) => repository.deleteEvent(event.id),
      itemBuilder: (context, event) => _EventTile(event),
      formBuilder: (context, edited) =>
          EventFormScreen(repository: repository, initial: edited),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile(this.event);

  final HealthEvent event;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = [
      eventTypeLabels[event.type] ?? event.type.wire,
      formatDateTime(event.occurredAt),
    ];
    return Row(
      children: [
        const Icon(Icons.event_note_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                parts.join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}