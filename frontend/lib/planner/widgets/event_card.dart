import 'package:flutter/material.dart';

import '../formats.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';

/// One event row with a context menu.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final PlannerEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final cancelled = event.status == EventStatus.cancelled;
    final muted = cancelled || event.status == EventStatus.completed;

    final duration = event.endAt.difference(event.startAt);
    final durationLabel = duration.inMinutes == 60
        ? '1h'
        : '${duration.inMinutes}m';

    return ListTile(
      onTap: onEdit,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: CircleAvatar(
        backgroundColor: colors.secondaryContainer,
        child: Icon(
          Icons.event,
          color: colors.onSecondaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        event.title,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: muted ? colors.outline : colors.onSurface,
              decoration: cancelled ? TextDecoration.lineThrough : null,
            ),
      ),
      subtitle: Text(
        [
          Formats.eventRangeLabel(event),
          if (event.location != null && event.location!.isNotEmpty)
            event.location!,
        ].join(' · '),
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: colors.onSurfaceVariant,
            ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!cancelled)
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                durationLabel,
                style: Theme.of(context).textTheme.labelSmall!.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}