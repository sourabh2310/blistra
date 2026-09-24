import 'package:flutter/material.dart';

import '../formats.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_status.dart';

/// Modern task card in the Home design language: rounded white card,
/// completion toggle, priority chip, due label.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.onCancel,
  });

  final PlannerTask task;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Only present for active tasks (cancelling a completed task is illegal).
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final done = task.status == TaskStatus.completed;
    final cancelled = task.status == TaskStatus.cancelled;
    final settled = done || cancelled;
    final dueLabel = Formats.taskScheduleLabel(task);
    final subtitle = [
      if (dueLabel.isNotEmpty) dueLabel,
      if (Formats.taskDurationLabel(task).isNotEmpty)
        Formats.taskDurationLabel(task),
      if (task.taskListName?.isNotEmpty == true) task.taskListName!,
    ].join(' · ');

    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: settled ? 0.72 : 1,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: settled ? 'Reopen task' : 'Mark complete',
                onPressed: onToggle,
                icon: Icon(
                  settled ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: settled
                      ? const Color(0xFF12A5A5)
                      : const Color(0xFF98A2B3),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: settled
                                  ? const Color(0xFF98A2B3)
                                  : Theme.of(context).colorScheme.onSurface,
                              decoration: cancelled
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PriorityDot(priority: task.priority),
                      ],
                    ),
                    if (subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            if (task.overdue && task.status.isActive)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: _Chip('Overdue',
                                    bg: Color(0xFFFDECEC),
                                    fg: Color(0xFFB42318)),
                              ),
                            Flexible(
                              child: Text(
                                subtitle,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: task.overdue &&
                                          task.status.isActive
                                      ? const Color(0xFFB42318)
                                       : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                      return;
                    case 'delete':
                      onDelete();
                      return;
                    case 'cancel':
                      onCancel?.call();
                      return;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('Edit')),
                  if (task.status.isActive)
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

class _PriorityDot extends StatelessWidget {
  const _PriorityDot({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      TaskPriority.high => const Color(0xFFE5484D),
      TaskPriority.medium => const Color(0xFFE8890C),
      TaskPriority.low => const Color(0xFF12A5A5),
    };
    final label = switch (priority) {
      TaskPriority.high => 'High',
      TaskPriority.medium => 'Med',
      TaskPriority.low => 'Low',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}
