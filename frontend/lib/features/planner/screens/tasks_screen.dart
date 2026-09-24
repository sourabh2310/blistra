import 'package:flutter/material.dart';

import '../../../features/app_scope.dart';
import '../models/task.dart';
import '../models/task_view.dart';
import '../planner_controller.dart';
import '../widgets/task_card.dart';
import '../widgets/status_views.dart';
import 'task_form_screen.dart';

/// Tasks tab: actionable work the user needs to complete.
///
/// Content-only widget (header + pill switcher live in [HomeScreen]).
/// Uses an inline "+ Add task" CTA — never a floating button that could
/// hide behind the global bottom navigation.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const _teal = Color(0xFF0C6B6B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planner = AppScope.of(context).planner;
      if (planner.tasks.isEmpty && !planner.loading) {
        planner.loadTasks();
      }
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
        return RefreshIndicator(
          color: _teal,
          onRefresh: planner.loadTasks,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(context, planner)),
              SliverToBoxAdapter(child: _filters(planner)),
              _bodySliver(context, planner),
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),
        );
      },
    );
  }

  Widget _header(BuildContext context, PlannerController planner) {
    final visible = _visibleTasks(planner);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tasks',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF101828))),
                Text(
                  visible.isEmpty
                      ? 'Actions to complete'
                      : '${visible.length} task${visible.length == 1 ? '' : 's'}',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF667085)),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _teal,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _openForm(context, planner),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add task'),
          ),
        ],
      ),
    );
  }

  Widget _filters(PlannerController planner) {
    const shown = [
      TaskView.all,
      TaskView.active,
      TaskView.completed,
      TaskView.overdue,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final view in shown)
            ChoiceChip(
              label: Text(_label(view)),
              selected: planner.taskView == view,
              selectedColor: const Color(0xFFE6F6F3),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w700,
                color: planner.taskView == view
                    ? _teal
                    : const Color(0xFF3E4A5A),
              ),
              side: BorderSide(
                color: planner.taskView == view
                    ? _teal
                    : const Color(0xFFE4E7EC),
              ),
              onSelected: (_) => planner.setTaskView(view),
            ),
        ],
      ),
    );
  }

  Widget _bodySliver(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.tasks.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }
    if (planner.error != null && planner.tasks.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child:
            ErrorRetry(message: planner.error!, onRetry: planner.loadTasks),
      );
    }
    final visible = _visibleTasks(planner);
    if (visible.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState(context, planner));
    }
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, index == 0 ? 12 : 8, 16, 0),
          child: TaskCard(
            task: visible[index],
            onToggle: () => visible[index].status.isActive
                ? planner.completeTask(visible[index].id)
                : planner.reopenTask(visible[index].id),
            onEdit: () =>
                _openForm(context, planner, task: visible[index]),
            onCancel: () => _confirm(
              context,
              'Cancel "${visible[index].title}"?',
              () => planner.cancelTask(visible[index].id),
            ),
            onDelete: () => _confirm(
              context,
              'Delete "${visible[index].title}"?',
              () => planner.deleteTask(visible[index].id),
            ),
          ),
        ),
        childCount: visible.length,
      ),
    );
  }

  List<PlannerTask> _visibleTasks(PlannerController planner) {
    final q = planner.searchQuery.trim().toLowerCase();
    if (q.isEmpty) return planner.tasks;
    return planner.tasks.where((t) {
      return t.title.toLowerCase().contains(q) ||
          (t.description?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  Widget _emptyState(BuildContext context, PlannerController planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF0EDE8)),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 30, color: _teal),
            ),
            const SizedBox(height: 12),
            const Text('No tasks yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Add something you need to get done.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085))),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _teal),
              onPressed: () => _openForm(context, planner),
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openForm(
    BuildContext context,
    PlannerController planner, {
    PlannerTask? task,
  }) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => TaskFormScreen(planner: planner, task: task)),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(task == null ? 'Task created' : 'Task updated')),
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
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed == true) {
      action();
    }
  }

  static String _label(TaskView view) => switch (view) {
        TaskView.all => 'All',
        TaskView.active => 'Open',
        TaskView.completed => 'Completed',
        TaskView.today => 'Due today',
        TaskView.overdue => 'Overdue',
        TaskView.upcoming => 'Upcoming',
      };
}
