import 'package:flutter/material.dart';

import '../formats.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';

/// Modern event card in the Home design language: time range first,
/// then title, location, and status — a scheduled commitment, not a task.
class EventCard extends StatelessWidget {
  const EventCard({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
    this.onToggleComplete,
    this.onCancel,
  });

  final PlannerEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleComplete;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final cancelled = event.status == EventStatus.cancelled;
    final done = event.status == EventStatus.completed;
    final muted = cancelled || done;
    final local = event.startAt.toLocal();

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: muted ? 0.72 : 1,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0EDE8)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                child: Column(
                  children: [
                    Text(
                      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0C6B6B)),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8890C),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: muted
                            ? const Color(0xFF98A2B3)
                            : const Color(0xFF101828),
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        Formats.eventRangeLabel(event),
                        if (event.location?.isNotEmpty == true)
                          event.location!,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
              if (onToggleComplete != null && !cancelled)
                IconButton(
                  tooltip: done ? 'Reopen' : 'Complete',
                  icon: Icon(
                    done ? Icons.check_circle : Icons.circle_outlined,
                    color: done
                        ? const Color(0xFF12A5A5)
                        : const Color(0xFF98A2B3),
                  ),
                  onPressed: onToggleComplete,
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                    case 'toggle':
                      onToggleComplete?.call();
                    case 'cancel':
                      onCancel?.call();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('Edit')),
                  if (onToggleComplete != null && !cancelled)
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(done ? 'Reopen' : 'Complete'),
                    ),
                  if (onCancel != null && !cancelled)
                    const PopupMenuItem(
                        value: 'cancel', child: Text('Cancel')),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
