import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/design_system.dart';
import '../../../features/app_scope.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../models/task_view.dart';
import '../planner_controller.dart';
import '../today_helpers.dart';
import '../widgets/status_views.dart';
import '../widgets/task_card.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) => RefreshIndicator(
        onRefresh: planner.loadTasks,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(planner)),
            SliverToBoxAdapter(child: _filters(planner)),
            ..._body(context, planner),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _header(PlannerController planner) {
    final visible = _visibleTasks(planner);
    final count = planner.taskView == TaskView.completed
        ? visible.length
        : visible.where((task) => task.status != TaskStatus.completed).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What do you need to get done?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.xs),
          Text('$count ${count == 1 ? 'task' : 'tasks'}', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _filters(PlannerController planner) {
    const views = [
      TaskView.all,
      TaskView.today,
      TaskView.upcoming,
      TaskView.overdue,
      TaskView.completed,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final view in views)
            ChoiceChip(
              label: Text(_label(view)),
              selected: planner.taskView == view,
              onSelected: (_) => planner.setTaskView(view),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.tasks.isEmpty) {
      return const [SliverToBoxAdapter(child: SkeletonLoader(rows: 5, rowHeight: 76))];
    }
    if (planner.error != null && planner.tasks.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorRetry(
            message: "Couldn't load your tasks.",
            onRetry: planner.loadTasks,
          ),
        ),
      ];
    }
    final visible = _visibleTasks(planner);
    if (visible.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _emptyState(
            title: planner.searchQuery.trim().isNotEmpty
                ? 'No matching tasks'
                : _emptyTitle(planner.taskView),
            message: planner.searchQuery.trim().isNotEmpty
                ? 'Try a different Planner search.'
                : _emptyMessage(planner.taskView),
          ),
        ),
      ];
    }
    if (planner.taskView == TaskView.completed) {
      return [
        _groupHeader('Completed', visible.length),
        _taskList(context, planner, visible),
      ];
    }
    final groups = groupTasksByDate(visible, DateTime.now());
    return [
      for (final group in groups) ...[
        _groupHeader(group.label, group.tasks.length),
        _taskList(context, planner, group.tasks),
      ],
    ];
  }

  Widget _groupHeader(String label, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$count', style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }

  Widget _taskList(BuildContext context, PlannerController planner, List<PlannerTask> tasks) {
    return SliverList.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TaskCard(
            task: task,
            onOpen: () => _openDetail(context, planner, task),
            onToggle: () => _runAction(
              context,
              () => task.status.isActive
                  ? planner.completeTask(task.id)
                  : planner.reopenTask(task.id),
            ),
            onEdit: () => _openForm(context, planner, task: task),
            onCancel: task.status.isActive
                ? () => _confirm(context, 'Cancel this task?', () => planner.cancelTask(task.id))
                : null,
            onDelete: () => _confirm(context, 'Delete this task?', () => planner.deleteTask(task.id)),
          ),
        );
      },
    );
  }

  Future<void> _openDetail(BuildContext context, PlannerController planner, PlannerTask task) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(planner: planner, taskId: task.id)),
    );
  }

  List<PlannerTask> _visibleTasks(PlannerController planner) {
    final query = planner.searchQuery.trim().toLowerCase();
    final tasks = List<PlannerTask>.from(planner.tasks);
    if (query.isEmpty) return tasks;
    return tasks.where((task) {
      return task.title.toLowerCase().contains(query) ||
          (task.description?.toLowerCase().contains(query) ?? false) ||
          (task.taskListName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  Widget _emptyState({required String title, required String message}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: AppCard(
        child: Column(
          children: [
            Icon(Icons.task_alt, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            const Text('Use the global Add button to create a task.'),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, PlannerController planner, {PlannerTask? task}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(planner: planner, task: task)),
    );
    if (saved == true && context.mounted) {
      showAppMessage(context, task == null ? 'Task created' : 'Task updated');
    }
  }

  Future<void> _confirm(BuildContext context, String title, Future<void> Function() action) async {
    final confirmed = await confirmAction(context, title: title, message: 'This action cannot be undone.');
    if (confirmed) await _runAction(context, action);
  }

  Future<void> _runAction(BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) showAppMessage(context, "Couldn't update this task.", error: true);
    }
  }

  static String _label(TaskView view) => switch (view) {
        TaskView.all => 'All',
        TaskView.today => 'Today',
        TaskView.upcoming => 'Upcoming',
        TaskView.overdue => 'Overdue',
        TaskView.completed => 'Completed',
        TaskView.active => 'Open',
      };

  static String _emptyTitle(TaskView view) => switch (view) {
        TaskView.today => 'Nothing due today',
        TaskView.upcoming => 'Nothing upcoming',
        TaskView.overdue => 'Nothing overdue',
        TaskView.completed => 'No completed tasks',
        _ => 'No tasks yet',
      };

  static String _emptyMessage(TaskView view) => switch (view) {
        TaskView.today => 'Your Planner has no tasks scheduled for today.',
        TaskView.upcoming => 'Tasks with future dates will appear here.',
        TaskView.overdue => 'You are caught up on overdue tasks.',
        TaskView.completed => 'Completed tasks will stay available here.',
        _ => 'Use the global Add button when there is something to get done.',
      };
}
