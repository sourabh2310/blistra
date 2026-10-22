import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../formats.dart';
import '../models/task.dart';
import '../models/task_priority.dart';
import '../models/task_reminder_mode.dart';
import '../models/task_status.dart';
import '../planner_controller.dart';
import '../widgets/planner_parts.dart';
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
    final settled = task != null && !task.status.isActive;
    return Scaffold(
      bottomNavigationBar: task == null
          ? null
          : StickyActionBar(
              label: settled ? 'Reopen task' : 'Complete task',
              busy: _working,
              onPressed: _toggle,
            ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            BlistraPageHeader(
              eyebrow: 'Task',
              title: task?.title ?? 'Task details',
              subtitle: task == null ? null : _summary(task),
              showAvatar: false,
              actions: [
                GlassIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit task',
                  onTap: task == null || _loading ? null : _openEdit,
                ),
                PopupMenuButton<_TaskAction>(
                  tooltip: 'More task actions',
                  enabled: task != null && !_working,
                  onSelected: (action) => action == _TaskAction.cancel ? _cancel() : _delete(),
                  itemBuilder: (context) => [
                    if (task?.status.isActive ?? false)
                      const PopupMenuItem(value: _TaskAction.cancel, child: Text('Cancel task')),
                    PopupMenuItem(
                      value: _TaskAction.delete,
                      child: Text('Delete task', style: TextStyle(color: BlistraColors.resolve(context).danger)),
                    ),
                  ],
                  child: const IgnorePointer(
                    child: GlassIconButton(icon: Icons.more_horiz, tooltip: null, onTap: null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading && task == null)
              const SkeletonLoader(rows: 4, rowHeight: 64)
            else if (_error != null && task == null)
              ErrorRetry(message: _error!, onRetry: _load)
            else if (task != null)
              ..._body(context, task),
          ],
        ),
      ),
    );
  }

  String _summary(PlannerTask task) {
    final status = switch (task.status) {
      TaskStatus.completed => 'Completed',
      TaskStatus.cancelled => 'Cancelled',
      TaskStatus.inProgress => 'In progress',
      TaskStatus.todo => task.overdue ? 'Overdue' : 'Open',
    };
    return [status, if (task.taskListName?.isNotEmpty == true) task.taskListName!].join(' · ');
  }

  List<Widget> _body(BuildContext context, PlannerTask task) {
    final colors = BlistraColors.resolve(context);
    final overdue = task.overdue && task.status.isActive;
    final schedule = Formats.taskScheduleLabel(task);
    final duration = Formats.taskDurationLabel(task);
    final when = task.startAt ?? task.dueDate;
    final time = task.startAt != null
        ? Formats.timeOfDay(task.startAt!.toLocal())
        : Formats.timeOfDay(task.dueTime);
    return [
      StatStrip(stats: [
        StatData(
          label: 'Status',
          value: switch (task.status) {
            TaskStatus.completed => 'Done',
            TaskStatus.cancelled => 'Cancelled',
            TaskStatus.inProgress => 'Started',
            TaskStatus.todo => 'Open',
          },
          sub: task.completedAt == null ? '' : 'on ${PlannerDates.short(task.completedAt!.toLocal())}',
          badge: overdue ? 'OVERDUE' : null,
          color: overdue ? colors.danger : null,
          icon: task.status == TaskStatus.completed ? Icons.check_rounded : Icons.radio_button_unchecked,
        ),
        StatData(
          label: 'Priority',
          value: switch (task.priority) {
            TaskPriority.high => 'High',
            TaskPriority.medium => 'Medium',
            TaskPriority.low => 'Low',
          },
          icon: Icons.flag_outlined,
        ),
        StatData(
          label: 'Due',
          value: when == null ? 'No date' : PlannerDates.relative(when.toLocal()),
          sub: time.isNotEmpty ? time : (when == null ? 'Any time' : 'No time set'),
          icon: Icons.event_outlined,
        ),
      ]),
      const SizedBox(height: 22),
      const SectionHeader(title: 'Details'),
      PagePad(
        GlassList(children: [
          GlassRow(
            leading: IconWell(Icons.schedule_rounded, color: overdue ? colors.danger : colors.accentText),
            title: schedule.isEmpty ? 'No date' : schedule,
            titleColor: overdue ? colors.danger : null,
            subtitle: 'Schedule',
          ),
          if (duration.isNotEmpty)
            GlassRow(
              leading: const IconWell(Icons.timelapse_rounded),
              title: duration,
              subtitle: 'Duration',
            ),
          if (task.taskListName?.isNotEmpty == true)
            GlassRow(
              leading: const IconWell(Icons.checklist_rtl_rounded),
              title: task.taskListName!,
              subtitle: 'List',
            ),
          if (task.reminderMode != TaskReminderMode.none)
            GlassRow(
              leading: const IconWell(Icons.notifications_none_rounded),
              title: task.reminderMode.label,
              subtitle: 'Reminder',
            ),
        ]),
      ),
      if (task.description?.isNotEmpty == true) ...[
        const SizedBox(height: 22),
        const SectionHeader(title: 'Notes'),
        PagePad(
          GlassCard(
            padding: const EdgeInsets.all(15),
            child: SizedBox(
              width: double.infinity,
              child: Text(
                task.description!,
                style: TextStyle(fontSize: 13.5, height: 1.45, color: colors.text),
              ),
            ),
          ),
        ),
      ],
    ];
  }
}

enum _TaskAction { cancel, delete }
