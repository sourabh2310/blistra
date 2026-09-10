import 'package:flutter/material.dart';

import '../../../features/app_scope.dart';
import '../models/planner_event.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../planner_controller.dart';
import '../widgets/event_card.dart';
import '../widgets/status_views.dart';
import '../widgets/task_card.dart';
import 'event_form_screen.dart';
import 'task_form_screen.dart';

/// The Today tab: an at-a-glance, Planner-scoped view of overdue tasks, tasks
/// due today and events overlapping today.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planner = AppScope.of(context).planner;
      if (planner.today == null) {
        planner.loadToday();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) {
        final today = planner.today;
        if (planner.loading && today == null) {
          return const Center(child: CircularProgressIndicator());
        }
        if (planner.error != null && today == null) {
          return ErrorRetry(message: planner.error!, onRetry: planner.loadToday);
        }
        if (today == null) {
          return ErrorRetry(message: 'Unable to load today', onRetry: planner.loadToday);
        }
        return RefreshIndicator(
          onRefresh: planner.loadToday,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              _SectionHeader('Overdue', count: today.overdueTasks.length),
              if (today.overdueTasks.isEmpty)
                const _InlineEmpty('Nothing overdue. Great work!')
              else
                for (final task in today.overdueTasks)
                  _taskCard(planner, task),
              const Divider(),
              _SectionHeader('Due today', count: today.todayTasks.length),
              if (today.todayTasks.isEmpty)
                const _InlineEmpty('No tasks due today.')
              else
                for (final task in today.todayTasks)
                  _taskCard(planner, task),
              const Divider(),
              _SectionHeader("Today's events", count: today.todayEvents.length),
              if (today.todayEvents.isEmpty)
                const _InlineEmpty('No events today.')
              else
                for (final event in today.todayEvents)
                  _eventCard(planner, event),
            ],
          ),
        );
      },
    );
  }

  Widget _taskCard(PlannerController planner, PlannerTask task) {
    return TaskCard(
      task: task,
      onToggle: () => task.status.isActive
          ? planner.completeTask(task.id)
          : planner.reopenTask(task.id),
      onEdit: () => _openTaskForm(planner, task),
      onCancel: () => planner.cancelTask(task.id),
      onDelete: () => _confirmDelete(
        'Delete "${task.title}"?',
        () => planner.deleteTask(task.id),
      ),
    );
  }

  Widget _eventCard(PlannerController planner, PlannerEvent event) {
    return EventCard(
      event: event,
      onEdit: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EventFormScreen(planner: planner, event: event),
        ),
      ),
      onDelete: () => _confirmDelete(
        'Delete "${event.title}"?',
        () => planner.deleteEvent(event.id),
      ),
    );
  }

  Future<void> _openTaskForm(PlannerController planner, PlannerTask task) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(planner: planner, task: task),
      ),
    );
  }

  Future<void> _confirmDelete(String message, Future<void> Function() action) async {
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 10,
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      ),
    );
  }
}