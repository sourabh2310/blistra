import 'package:flutter/material.dart';

import '../formats.dart';
import '../models/task.dart';

/// One tappable task row with a completion toggle and a context menu.
class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onCancel,
  });

  final PlannerTask task;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Only present for active tasks (cancelling a completed task is illegal).
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done = task.status == TaskStatus.completed;
    final cancelled = task.status == TaskStatus.cancelled;

    final titleColor = done || cancelled ? colors.outline : colors.onSurface;
    final subtitle = task.dueDate != null
        ? '${Formats.taskDueLabel(task)}'
            '${task.taskListName != null ? ' · ${task.taskListName}' : ''}'
        : task.taskListName;

    return ListTile(
      onTap: onEdit,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: IconButton(
        tooltip: done ? 'Reopen task' : 'Mark complete',
        onPressed: onToggle,
        icon: Icon(
          done ? Icons.check_circle : Icons.radio_button_unchecked,
          color: done ? colors.primary : colors.outline,
        ),
      ),
      title: Text(
        task.title,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: titleColor),
      ),
      subtitle: subtitle == null || subtitle.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.overdue && task.status.isActive)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _Chip('Overdue', color: colors.error),
                  ),
                Flexible(
                  child: Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: task.overdue && task.status.isActive
                              ? colors.error
                              : colors.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'edit':
              onEdit();
            case 'delete':
              onDelete();
            case 'cancel':
              onCancel?.call();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (task.status.isActive)
            const PopupMenuItem(value: 'cancel', child: Text('Cancel')),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label, {required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(color: color),
      ),
    );
  }
}