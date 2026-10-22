import 'package:flutter/material.dart';

import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../features/app_scope.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../models/task_view.dart';
import '../planner_controller.dart';
import '../today_helpers.dart';
import '../widgets/planner_parts.dart';
import '../widgets/status_views.dart';
import '../widgets/task_card.dart';
import 'events_screen.dart';
import 'task_detail_screen.dart';
import 'task_form_screen.dart';

/// Planner "Upcoming" tab: tasks (and, for date lenses, events) grouped by
/// day, with All / Today / Upcoming / Overdue / Completed lenses.
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const _views = [
    TaskView.all,
    TaskView.today,
    TaskView.upcoming,
    TaskView.overdue,
    TaskView.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () => Future.wait([planner.loadTasks(), planner.loadEvents()]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
          children: [
            ChipRow(
              labels: [for (final view in _views) _label(view)],
              selected: _views.contains(planner.taskView) ? _views.indexOf(planner.taskView) : null,
              onSelected: (index) => planner.setTaskView(_views[index]),
            ),
            const SizedBox(height: 18),
            ..._body(context, planner),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.tasks.isEmpty) {
      return const [SkeletonLoader(rows: 5, rowHeight: 64)];
    }
    if (planner.error != null && planner.tasks.isEmpty) {
      return [
        ErrorRetry(
          message: "Couldn't load your tasks.",
          onRetry: planner.loadTasks,
        ),
      ];
    }
    final tasks = _visibleTasks(planner);
    if (planner.taskView == TaskView.completed) {
      if (tasks.isEmpty) return [_empty(planner)];
      return [
        SectionHeader(title: 'Completed', actionLabel: '${tasks.length}'),
        PagePad(GlassList(children: [for (final task in tasks) taskRow(context, planner, task)])),
      ];
    }
    final groups = _groups(planner, tasks, _visibleEvents(planner));
    if (groups.isEmpty) return [_empty(planner)];
    return [
      for (final group in groups) ...[
        SectionHeader(title: group.label, actionLabel: '${group.items.length}'),
        PagePad(
          GlassList(children: [
            for (final item in group.items)
              if (item.task != null)
                taskRow(context, planner, item.task!)
              else
                eventRow(context, planner, item.event!),
          ]),
        ),
        const SizedBox(height: 22),
      ],
    ];
  }

  Widget _empty(PlannerController planner) {
    final searching = planner.searchQuery.trim().isNotEmpty;
    return PagePad(
      EmptyCard(
        message: searching
            ? 'No matching tasks. Try a different Planner search.'
            : '${_emptyTitle(planner.taskView)}. ${_emptyMessage(planner.taskView)}',
      ),
    );
  }

  /// Overdue first, then one group per day in date order, then undated.
  List<_Group> _groups(PlannerController planner, List<PlannerTask> tasks, List<PlannerEvent> events) {
    final overdue = <_Item>[];
    final undated = <_Item>[];
    final days = <DateTime, List<_Item>>{};
    for (final task in tasks.where((task) => task.status != TaskStatus.completed)) {
      final day = taskScheduleDay(task);
      if (task.overdue) {
        overdue.add(_Item.task(task));
      } else if (day == null) {
        undated.add(_Item.task(task));
      } else {
        days.putIfAbsent(day, () => []).add(_Item.task(task));
      }
    }
    for (final event in events) {
      days.putIfAbsent(PlannerDates.dateOnly(event.startAt.toLocal()), () => []).add(_Item.event(event));
    }
    final ordered = days.keys.toList()..sort();
    return [
      if (overdue.isNotEmpty) _Group('Overdue', overdue),
      for (final day in ordered) _Group(PlannerDates.relative(day), days[day]!..sort(_byTime)),
      if (undated.isNotEmpty) _Group('No date', undated),
    ];
  }

  static int _byTime(_Item a, _Item b) {
    final ta = a.time;
    final tb = b.time;
    if (ta == null && tb == null) return a.title.compareTo(b.title);
    if (ta == null) return 1;
    if (tb == null) return -1;
    return ta.compareTo(tb);
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

  /// Events join the date lenses only: All and Upcoming from today on,
  /// Today for today. Cancelled events stay on the Calendar tab.
  List<PlannerEvent> _visibleEvents(PlannerController planner) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final query = planner.searchQuery.trim().toLowerCase();
    bool inLens(DateTime day) => switch (planner.taskView) {
          TaskView.all || TaskView.active => !day.isBefore(today),
          TaskView.today => day == today,
          TaskView.upcoming => day.isAfter(today),
          _ => false,
        };
    return planner.events.where((event) {
      if (event.status == EventStatus.cancelled) return false;
      if (!inLens(PlannerDates.dateOnly(event.startAt.toLocal()))) return false;
      if (query.isEmpty) return true;
      return event.title.toLowerCase().contains(query) ||
          (event.description?.toLowerCase().contains(query) ?? false) ||
          (event.location?.toLowerCase().contains(query) ?? false);
    }).toList();
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

/// A task row with open, toggle, edit, cancel and delete wired to [planner].
Widget taskRow(BuildContext context, PlannerController planner, PlannerTask task) {
  return TaskCard(
    task: task,
    onOpen: () => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => TaskDetailScreen(planner: planner, taskId: task.id)),
    ),
    onToggle: () => _runTaskAction(
      context,
      () => task.status.isActive ? planner.completeTask(task.id) : planner.reopenTask(task.id),
    ),
    onEdit: () => _openTaskForm(context, planner, task: task),
    onCancel: task.status.isActive
        ? () => _confirmTask(context, 'Cancel this task?', () => planner.cancelTask(task.id))
        : null,
    onDelete: () => _confirmTask(context, 'Delete this task?', () => planner.deleteTask(task.id)),
  );
}

Future<void> _openTaskForm(BuildContext context, PlannerController planner, {PlannerTask? task}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => TaskFormScreen(planner: planner, task: task)),
  );
  if (saved == true && context.mounted) {
    showAppMessage(context, task == null ? 'Task created' : 'Task updated');
  }
}

Future<void> _confirmTask(BuildContext context, String title, Future<void> Function() action) async {
  final confirmed = await confirmAction(context, title: title, message: 'This action cannot be undone.');
  if (confirmed && context.mounted) await _runTaskAction(context, action);
}

Future<void> _runTaskAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) showAppMessage(context, "Couldn't update this task.", error: true);
  }
}

class _Item {
  _Item.task(PlannerTask this.task) : event = null;
  _Item.event(PlannerEvent this.event) : task = null;

  final PlannerTask? task;
  final PlannerEvent? event;

  String get title => task?.title ?? event!.title;

  DateTime? get time {
    final t = task;
    if (t == null) return event!.startAt;
    if (t.startAt != null) return t.startAt;
    if (taskHasExplicitTime(t)) return t.dueAt;
    return null;
  }
}

class _Group {
  const _Group(this.label, this.items);

  final String label;
  final List<_Item> items;
}
