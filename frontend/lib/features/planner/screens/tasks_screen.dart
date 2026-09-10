import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../planner/models/task.dart';
import '../planner/models/task_view.dart';
import '../planner/planner_controller.dart';
import '../planner/widgets/task_card.dart';
import '../planner/widgets/status_views.dart';
import 'task_form_screen.dart';

/// The Tasks tab: a filterable, pageable list of the user's tasks.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planner = AppScope.of(context).planner;
      if (planner.taskLists.isEmpty) {
        planner.loadTaskLists();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) {
        return Scaffold(
          body: Column(
            children: [
              _TaskFilters(planner: planner),
              Expanded(child: _buildBody(planner)),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openForm(context, planner),
            tooltip: 'New task',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Widget _buildBody(PlannerController planner) {
    if (planner.loading && planner.tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (planner.error != null && planner.tasks.isEmpty) {
      return ErrorRetry(message: planner.error!, onRetry: planner.loadTasks);
    }
    if (planner.tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: planner.loadTasks,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.task_alt,
              message: 'No tasks here yet.\nTap + to create one.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: planner.loadTasks,
      child: ListView.separated(
        itemCount: planner.tasks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final task = planner.tasks[index];
          return TaskCard(
            task: task,
            onToggle: () => task.status.isActive
                ? planner.completeTask(task.id)
                : planner.reopenTask(task.id),
            onEdit: () => _openForm(context, planner, task: task),
            onCancel: () => _confirm(
              context,
              'Cancel "${task.title}"?',
              () => planner.cancelTask(task.id),
            ),
            onDelete: () => _confirm(
              context,
              'Delete "${task.title}"?',
              () => planner.deleteTask(task.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    PlannerController planner, {
    PlannerTask? task,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TaskFormScreen(planner: planner, task: task)),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(task == null ? 'Task created' : 'Task updated')),
      );
    }
  }

  Future<void> _confirm(
    BuildContext context,
    String message,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) {
      action();
    }
  }
}

class _TaskFilters extends StatelessWidget {
  const _TaskFilters({required this.planner});

  final PlannerController planner;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            children: [
              for (final view in TaskView.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_label(view)),
                    selected: planner.taskView == view,
                    onSelected: (_) => planner.setTaskView(view),
                  ),
                ),
            ],
          ),
        ),
        if (planner.taskLists.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.filter_list, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String?>(
                    value: planner.taskListFilter,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('All lists'),
                      ),
                      for (final list in planner.taskLists)
                        DropdownMenuItem<String?>(
                          value: list.id,
                          child: Text(list.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (value) => planner.setTaskListFilter(value),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _label(TaskView view) => switch (view) {
        TaskView.all => 'All',
        TaskView.active => 'Active',
        TaskView.completed => 'Completed',
        TaskView.today => 'Due today',
        TaskView.overdue => 'Overdue',
        TaskView.upcoming => 'Upcoming',
      };
}