import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../formats.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import 'planner_parts.dart';

/// Colour for event icon wells, shared by every Planner view.
Color plannerEventColor(BlistraColors colors) => colors.data[1];

/// One event as a [GlassRow] for use inside a [GlassList]: calendar icon
/// well, title, time range and location, and an actions menu.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.onToggleComplete,
    this.onCancel,
  });

  final PlannerEvent event;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final cancelled = event.status == EventStatus.cancelled;
    final done = event.status == EventStatus.completed;
    final settled = done || cancelled;

    return GlassRow(
      title: event.title,
      subtitle: [
        if (cancelled) 'Cancelled',
        if (done) 'Completed',
        Formats.eventRangeLabel(event),
        if (event.location?.isNotEmpty == true) event.location!,
      ].join(' · '),
      done: settled,
      onTap: onOpen,
      leading: IconWell(
        settled ? Icons.event_available_outlined : Icons.event_outlined,
        color: plannerEventColor(colors),
      ),
      trailing: RowMenu(
        tooltip: 'Event actions',
        items: [
          RowMenuItem('Edit', onEdit),
          if (onToggleComplete != null)
            RowMenuItem(settled ? 'Reopen' : 'Complete', onToggleComplete!),
          if (onCancel != null && !cancelled) RowMenuItem('Cancel', onCancel!),
          RowMenuItem('Delete', onDelete, destructive: true),
        ],
      ),
    );
  }
}
