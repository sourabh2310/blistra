import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../formats.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import 'planner_parts.dart';

/// One task as a [GlassRow] for use inside a [GlassList]: completion check,
/// title, schedule and list, priority pill and an actions menu.
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
    final colors = BlistraColors.resolve(context);
    final done = task.status == TaskStatus.completed;
    final cancelled = task.status == TaskStatus.cancelled;
    final settled = done || cancelled;
    final overdue = task.overdue && task.status.isActive;
    final subtitle = [
      if (overdue) 'Overdue',
      if (cancelled) 'Cancelled',
      if (Formats.taskScheduleLabel(task).isNotEmpty)
        Formats.taskScheduleLabel(task),
      if (Formats.taskDurationLabel(task).isNotEmpty)
        Formats.taskDurationLabel(task),
      if (task.taskListName?.isNotEmpty == true) task.taskListName!,
    ].join(' · ');

    return GlassRow(
      title: task.title,
      subtitle: subtitle,
      subtitleColor: overdue ? colors.danger : null,
      done: settled,
      onTap: onOpen,
      leading: CheckCircle(
        checked: settled,
        urgent: overdue,
        onTap: onToggle,
        semanticLabel: settled ? 'Reopen task' : 'Mark complete',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!settled) PriorityPill(task.priority),
          RowMenu(
            tooltip: 'Task actions',
            items: [
              RowMenuItem('Edit', onEdit),
              if (task.status.isActive && onCancel != null)
                RowMenuItem('Cancel', onCancel!),
              RowMenuItem('Delete', onDelete, destructive: true),
            ],
          ),
        ],
      ),
    );
  }
}
