import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../formats.dart';
import '../models/task.dart';
import '../models/task_reminder_mode.dart';
import '../models/task_status.dart';
import '../planner_controller.dart';
import '../widgets/status_views.dart';
import 'task_form_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.planner,
    required this.taskId,
  });

  final PlannerController planner;
  final String taskId;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  PlannerTask? _task;
  String? _error;
  bool _loading = true;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final task = await widget.planner.loadTask(widget.taskId);
      if (mounted) setState(() => _task = task);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't load this task.");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEdit() async {
    final task = _task;
    if (task == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(planner: widget.planner, task: task),
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _toggle() async {
    final task = _task;
    if (task == null) return;
    setState(() => _working = true);
    try {
      if (task.status.isActive) {
        await widget.planner.completeTask(task.id);
      } else {
        await widget.planner.reopenTask(task.id);
      }
      await _load();
    } catch (_) {
      if (mounted) showAppMessage(context, "Couldn't update this task.", error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _cancel() async {
    final task = _task;
    if (task == null) return;
    setState(() => _working = true);
    try {
      await widget.planner.cancelTask(task.id);
      await _load();
    } catch (_) {
      if (mounted) showAppMessage(context, "Couldn't cancel this task.", error: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _delete() async {
    final task = _task;
    if (task == null) return;
    final confirmed = await confirmAction(
      context,
      title: 'Delete this task?',
      message: 'This cannot be undone.',
    );
    if (!confirmed || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.planner.deleteTask(task.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) showAppMessage(context, "Couldn't delete this task.", error: true);
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          TextButton(
            onPressed: task == null || _loading ? null : _openEdit,
            child: const Text('Edit'),
          ),
        ],
      ),
      body: _loading && task == null
          ? const SkeletonLoader(rows: 4)
          : _error != null && task == null
              ? ErrorRetry(message: _error!, onRetry: _load)
              : task == null
                  ? const SizedBox.shrink()
                  : _body(context, task),
    );
  }

  Widget _body(BuildContext context, PlannerTask task) {
    final theme = Theme.of(context);
    final done = task.status == TaskStatus.completed;
    final cancelled = task.status == TaskStatus.cancelled;
    final settled = done || cancelled;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: cancelled ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  StatusChip(
                    label: done
                        ? 'Completed'
                        : cancelled
                            ? 'Cancelled'
                            : task.overdue
                                ? 'Overdue'
                                : 'Open',
                    color: done
                        ? theme.colorScheme.primary
                        : cancelled || task.overdue
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                    icon: done ? Icons.check : Icons.circle_outlined,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _DetailLine(icon: Icons.schedule, label: 'Schedule', value: Formats.taskScheduleLabel(task)),
              if (Formats.taskDurationLabel(task).isNotEmpty)
                _DetailLine(icon: Icons.timelapse, label: 'Duration', value: Formats.taskDurationLabel(task)),
              if (task.taskListName?.isNotEmpty == true)
                _DetailLine(icon: Icons.checklist_outlined, label: 'List', value: task.taskListName!),
              if (task.reminderMode != TaskReminderMode.none)
                _DetailLine(icon: Icons.notifications_none, label: 'Reminder', value: task.reminderMode.label),
              if (task.description?.isNotEmpty == true) ...[
                const Divider(height: AppSpacing.xxl),
                Text(task.description!, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        FilledButton.icon(
          onPressed: _working ? null : _toggle,
          icon: _working
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(settled ? Icons.replay : Icons.check),
          label: Text(settled ? 'Reopen task' : 'Complete task'),
        ),
        if (task.status.isActive)
          TextButton.icon(
            onPressed: _working ? null : _cancel,
            icon: const Icon(Icons.block),
            label: const Text('Cancel task'),
          ),
        TextButton.icon(
          onPressed: _working ? null : _delete,
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete task'),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelMedium),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
