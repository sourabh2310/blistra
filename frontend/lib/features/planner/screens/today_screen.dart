import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/quick_add.dart';
import '../../../features/app_scope.dart';
import '../../dashboard/models/dashboard_response.dart';
import '../../diet/screens/meal_detail_screen.dart';
import '../../habits/habits_controller.dart';
import '../../habits/habits_scope.dart';
import '../../habits/screens/habit_detail_screen.dart';
import '../../health/health_repository.dart';
import '../../health/presentation/appointments_screen.dart';
import '../../medicines/pages/medicine_detail_page.dart';
import '../formats.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../models/schedule_view.dart';
import '../models/task.dart';
import '../models/task_reminder_mode.dart';
import '../models/task_status.dart';
import '../planner_controller.dart';
import '../today_helpers.dart';
import '../widgets/event_card.dart';
import '../widgets/planner_parts.dart';
import '../widgets/status_views.dart';
import 'event_detail_screen.dart';
import 'list_detail_screen.dart';
import 'task_detail_screen.dart';

/// Planner "Today" tab: progress, overdue tasks, the selected day's tasks,
/// events and other modules' items in time order, then the user's lists.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, this.onShowLists});

  /// Opens the Lists tab from the "All" action.
  final VoidCallback? onShowLists;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final Set<_RowKind> _kinds = {};
  bool? _completedFilter;
  bool _hideCompleted = false;
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final planner = scope.planner;
    return ListenableBuilder(
      listenable: Listenable.merge([planner, scope.dashboard]),
      builder: (context, _) => RefreshIndicator(
        onRefresh: () async {
          await planner.loadSchedule();
          await planner.loadToday();
          await planner.loadTaskLists();
          await _refreshDashboard(scope);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
          children: _content(context, planner, scope.dashboard.dashboard),
        ),
      ),
    );
  }

  Future<void> _refreshDashboard(AppScope scope) async {
    try {
      await scope.dashboard.refresh(
        date: DateTime.now(),
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } catch (_) {}
  }

  List<Widget> _content(BuildContext context, PlannerController planner, DashboardResponse? dashboard) {
    if ((planner.scheduleLoading || planner.loading) && planner.schedule == null) {
      return const [SkeletonLoader(rows: 5, rowHeight: 64)];
    }
    if (planner.scheduleError != null && planner.schedule == null) {
      return [
        ErrorRetry(
          message: "Couldn't load your schedule.",
          onRetry: planner.loadSchedule,
        ),
      ];
    }
    final rows = _visibleRows(planner, dashboard);
    final overdue = planner.isTodaySelected ? rows.where(_isOverdue).toList() : <_Row>[];
    final main = rows.where((row) => !overdue.contains(row)).toList();
    final week = planner.scope == ScheduleScope.week;
    return [
      PagePad(_statusCard(context, planner, rows, overdue.length)),
      if (overdue.isNotEmpty) ...[
        const SizedBox(height: 22),
        const SectionHeader(title: 'Overdue'),
        PagePad(GlassList(children: [for (final row in overdue) _rowTile(context, row, overdue: true)])),
      ],
      const SizedBox(height: 22),
      SectionHeader(
        title: _mainTitle(planner),
        actionLabel: _filterCount == 0 ? 'Filters' : 'Filters · $_filterCount',
        onAction: _showFilters,
      ),
      if (rows.isEmpty)
        PagePad(_emptyCard(context, planner))
      else if (main.isEmpty)
        const PagePad(EmptyCard(message: 'Nothing else scheduled.'))
      else if (week)
        ..._weekGroups(context, main)
      else
        PagePad(GlassList(children: [for (final row in main) _rowTile(context, row)])),
      ..._lists(context, planner),
    ];
  }

  // --- Status -----------------------------------------------------------

  Widget _statusCard(BuildContext context, PlannerController planner, List<_Row> rows, int overdueCount) {
    final colors = BlistraColors.resolve(context);
    final summary = computeTodaySummary([
      for (final row in rows) TimelineEntry(at: row.at, title: row.title, source: row.kind.name, done: row.done),
    ]);
    final allTasks = rows.every((row) => row.kind == _RowKind.task);
    final noun = allTasks
        ? (summary.remaining == 1 ? 'task' : 'tasks')
        : (summary.remaining == 1 ? 'item' : 'items');
    final title = summary.total == 0
        ? 'Nothing planned'
        : summary.remaining == 0
            ? 'All done'
            : '${summary.remaining} $noun left';
    final now = DateTime.now();
    final events = rows.where((row) => row.kind == _RowKind.event && !row.done).toList();
    final next = events.where((row) => row.at.isAfter(now)).toList();
    final subtitle = [
      if (overdueCount > 0) '$overdueCount overdue',
      if (planner.isTodaySelected && next.isNotEmpty)
        'next event at ${Formats.timeOfDay(next.first.at)}'
      else if (events.isNotEmpty)
        '${events.length} ${events.length == 1 ? 'event' : 'events'}',
    ].join(' · ');
    final week = planner.scope == ScheduleScope.week;
    return StatusCard(
      caption: week
          ? 'Week of ${PlannerDates.short(planner.selectedDate)}'
          : planner.isTodaySelected
              ? 'Today'
              : PlannerDates.short(planner.selectedDate),
      title: title,
      subtitle: subtitle.isEmpty ? null : subtitle,
      leading: ProgressRing(
        progress: summary.fraction,
        size: 62,
        stroke: 6,
        child: Text(
          '${summary.completed}/${summary.total}',
          style: BlistraText.serif(15, colors.text).copyWith(fontFeatures: BlistraText.tabular),
        ),
      ),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _NavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: week ? 'Previous week' : 'Previous day',
                onTap: planner.scheduleLoading ? null : planner.previousDay,
              ),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                tooltip: week ? 'Next week' : 'Next day',
                onTap: planner.scheduleLoading ? null : planner.nextDay,
              ),
            ],
          ),
          if (!planner.isTodaySelected) ...[
            const SizedBox(height: 6),
            Pill('Today', onTap: planner.goToToday),
          ],
        ],
      ),
    );
  }

  String _mainTitle(PlannerController planner) {
    if (planner.scope == ScheduleScope.week) return 'This week';
    return PlannerDates.relative(planner.selectedDate);
  }

  bool _isOverdue(_Row row) {
    final task = row.task;
    return task != null && task.overdue && task.status.isActive;
  }

  // --- Rows -------------------------------------------------------------

  List<Widget> _weekGroups(BuildContext context, List<_Row> rows) {
    final colors = BlistraColors.resolve(context);
    final days = <DateTime, List<_Row>>{};
    for (final row in rows) {
      days.putIfAbsent(PlannerDates.dateOnly(row.at), () => []).add(row);
    }
    final ordered = days.keys.toList()..sort();
    return [
      for (final day in ordered) ...[
        PagePad(
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 4, 0, 8),
            child: Text(
              PlannerDates.relative(day).toUpperCase(),
              style: BlistraText.caption(colors.muted),
            ),
          ),
        ),
        PagePad(GlassList(children: [for (final row in days[day]!) _rowTile(context, row)])),
        const SizedBox(height: 12),
      ],
    ];
  }

  Widget _rowTile(BuildContext context, _Row row, {bool overdue = false}) {
    final colors = BlistraColors.resolve(context);
    final task = row.task;
    final Widget leading;
    if (task != null) {
      leading = CheckCircle(
        checked: row.done,
        urgent: _isOverdue(row),
        busy: _busy.contains(task.id),
        semanticLabel: row.done ? 'Reopen task' : 'Mark complete',
        onTap: () => _toggleTask(context, task),
      );
    } else {
      leading = IconWell(_sourceIcon(row.kind), color: _kindColor(colors, row.kind));
    }
    final when = overdue ? _overdueLabel(row) : (row.timed ? row.timeLabel : 'Any time');
    return GlassRow(
      leading: leading,
      title: row.title,
      subtitle: [when, if (row.detail.isNotEmpty) row.detail].join(' · '),
      subtitleColor: overdue ? colors.danger : null,
      done: row.done,
      onTap: () => _openRow(context, row),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (row.reminder != TaskReminderMode.none && !row.done)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.notifications_none_rounded, size: 16, color: colors.muted),
            ),
          if (task != null && !row.done) PriorityPill(task.priority),
        ],
      ),
    );
  }

  String _overdueLabel(_Row row) {
    final task = row.task!;
    final due = (task.dueAt ?? task.dueDate ?? task.startAt)?.toLocal();
    if (due == null) return 'Overdue';
    return PlannerDates.relative(due);
  }

  Future<void> _toggleTask(BuildContext context, PlannerTask task) async {
    final planner = AppScope.of(context).planner;
    setState(() => _busy.add(task.id));
    try {
      if (task.status.isActive) {
        await planner.completeTask(task.id);
      } else {
        await planner.reopenTask(task.id);
      }
    } catch (_) {
      if (context.mounted) showAppMessage(context, "Couldn't update this task.", error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(task.id));
    }
  }

  Widget _emptyCard(BuildContext context, PlannerController planner) {
    if (_hasActiveFilters) {
      return EmptyCard(
        message: 'No schedule items match these filters.',
        action: 'Clear filters',
        onAction: _clearFilters,
      );
    }
    return EmptyCard(
      message: 'No tasks or events scheduled.',
      action: 'Add',
      onAction: () async {
        final action = await showQuickAdd(context);
        if (action != null && context.mounted) await openQuickAddCreation(context, action);
      },
    );
  }

  List<Widget> _lists(BuildContext context, PlannerController planner) {
    final lists = planner.taskLists;
    if (lists.isEmpty) return const [];
    return [
      const SizedBox(height: 22),
      SectionHeader(
        title: 'Lists',
        actionLabel: widget.onShowLists == null ? null : 'All ›',
        onAction: widget.onShowLists,
      ),
      ChipRow(
        labels: [for (final list in lists) '${list.name}  ${list.taskCount}'],
        icons: [for (final _ in lists) Icons.checklist_rtl_rounded],
        selected: null,
        onSelected: (index) => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => ListDetailScreen(planner: planner, listId: lists[index].id)),
        ),
      ),
    ];
  }

  // --- Filters ----------------------------------------------------------

  int get _filterCount => _kinds.length + (_completedFilter == null ? 0 : 1) + (_hideCompleted ? 1 : 0);

  bool get _hasActiveFilters => _filterCount > 0;

  void _clearFilters() {
    setState(() {
      _kinds.clear();
      _completedFilter = null;
      _hideCompleted = false;
    });
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<_FilterSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _FilterSheet(
        selectedKinds: _kinds,
        completed: _completedFilter,
        hideCompleted: _hideCompleted,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _kinds
        ..clear()
        ..addAll(result.kinds);
      _completedFilter = result.completed;
      _hideCompleted = result.hideCompleted;
    });
  }

  // --- Data -------------------------------------------------------------

  List<_Row> _visibleRows(PlannerController planner, DashboardResponse? dashboard) {
    final rows = _rows(planner, dashboard)
        .where((row) => !row.cancelled)
        .where((row) => _kinds.isEmpty || _kinds.contains(row.kind))
        .where((row) => !_hideCompleted || !row.done)
        .where((row) => _completedFilter == null || row.done == _completedFilter)
        .toList();
    rows.sort((a, b) {
      if (a.timed != b.timed) return a.timed ? -1 : 1;
      return a.timed ? a.at.compareTo(b.at) : a.title.compareTo(b.title);
    });
    return rows;
  }

  Future<void> _openRow(BuildContext context, _Row row) async {
    switch (row.kind) {
      case _RowKind.task:
        await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => TaskDetailScreen(planner: AppScope.of(context).planner, taskId: row.task!.id)));
        return;
      case _RowKind.event:
        await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => EventDetailScreen(planner: AppScope.of(context).planner, eventId: row.event!.id)));
        return;
      case _RowKind.medicine:
        await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => MedicineDetailPage(medicineId: row.id!)));
        return;
      case _RowKind.habit:
        final controller = context.read<HabitsController>();
        await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => HabitsScope(controller: controller, child: HabitDetailScreen(habitId: row.id!))));
        return;
      case _RowKind.meal:
        await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => MealDetailScreen(mealId: row.id!)));
        return;
      case _RowKind.appointment:
        final repository = context.read<HealthRepository>();
        await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => AppointmentsScreen(repository: repository)));
        return;
    }
  }

  List<_Row> _rows(PlannerController planner, DashboardResponse? dashboard) {
    final query = planner.searchQuery.trim().toLowerCase();
    final rows = <_Row>[];
    final seenTasks = <String>{};
    for (final event in planner.scheduleEventsOrdered.where((event) => event.status != EventStatus.cancelled)) {
      if (!_matches(event.title, event.description, event.location, query)) continue;
      final start = event.startAt.toLocal();
      final end = event.endAt.toLocal();
      rows.add(_Row(
        at: start,
        title: event.title,
        detail: event.location?.isNotEmpty == true ? event.location! : 'Event',
        kind: _RowKind.event,
        timed: true,
        done: event.status == EventStatus.completed,
        timeLabel: '${_time(start)} – ${_time(end)}',
        event: event,
      ));
    }
    for (final task in planner.scheduleTasksOrdered) {
      if (!_matches(task.title, task.description, task.taskListName, query)) continue;
      seenTasks.add(task.id);
      final timed = taskHasExplicitTime(task);
      final start = (task.startAt ?? task.dueAt ?? task.dueDate)?.toLocal() ?? planner.selectedDate;
      final end = task.endAt?.toLocal();
      rows.add(_Row(
        at: start,
        title: task.title,
        detail: _taskDetail(task),
        kind: _RowKind.task,
        timed: timed,
        done: task.status == TaskStatus.completed,
        timeLabel: timed ? _taskTime(task, start, end) : 'Any time',
        task: task,
        reminder: task.reminderMode,
      ));
    }
    if (planner.isTodaySelected) {
      for (final task in planner.today?.overdueTasks ?? const <PlannerTask>[]) {
        if (seenTasks.contains(task.id) || !_matches(task.title, task.description, task.taskListName, query)) continue;
        final at = (task.dueAt ?? task.dueDate)?.toLocal() ?? planner.selectedDate;
        rows.add(_Row(at: at, title: task.title, detail: _taskDetail(task), kind: _RowKind.task, timed: taskHasExplicitTime(task), done: false, timeLabel: 'Overdue', task: task, reminder: task.reminderMode));
      }
    }
    if (planner.isTodaySelected && dashboard != null) {
      final medicines = dashboard.medicines;
      if (medicines != null && !medicines.unavailable) {
        for (final dose in medicines.dosesToday) {
          final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(dose.medicineName, null, null, query)) continue;
          final status = dose.status.toUpperCase();
          rows.add(_Row(at: at, title: dose.medicineName, detail: 'Medicine', kind: _RowKind.medicine, timed: true, done: status == 'TAKEN', cancelled: status == 'SKIPPED', timeLabel: _time(at), id: dose.medicineId));
        }
      }
      final habits = dashboard.habits;
      if (habits != null && !habits.unavailable) {
        for (final habit in habits.todayHabits) {
          if (!_matches(habit.name, null, null, query)) continue;
          rows.add(_Row(at: planner.selectedDate, title: habit.name, detail: 'Habit', kind: _RowKind.habit, timed: false, done: habit.completedToday, timeLabel: 'Any time', id: habit.id));
        }
      }
      final diet = dashboard.diet;
      if (diet != null && !diet.unavailable) {
        for (final meal in diet.meals) {
          final at = DateTime.tryParse(meal.consumedAt ?? '')?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(_mealTitle(meal.type), null, null, query)) continue;
          rows.add(_Row(at: at, title: _mealTitle(meal.type), detail: 'Meal', kind: _RowKind.meal, timed: true, done: true, timeLabel: _time(at), id: meal.id));
        }
      }
      final health = dashboard.health;
      if (health != null && !health.unavailable) {
        for (final appointment in health.upcomingAppointments) {
          final at = DateTime.tryParse(appointment.scheduledAt)?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(appointment.title, null, null, query)) continue;
          final status = (appointment.status ?? '').toUpperCase();
          rows.add(_Row(at: at, title: appointment.title, detail: 'Appointment', kind: _RowKind.appointment, timed: true, done: status == 'COMPLETED', cancelled: status == 'CANCELLED', timeLabel: _time(at), id: appointment.id));
        }
      }
    }
    return rows;
  }

  String _taskDetail(PlannerTask task) {
    final parts = <String>[];
    if (task.taskListName?.isNotEmpty == true) parts.add(task.taskListName!);
    final duration = Formats.taskDurationLabel(task);
    if (duration.isNotEmpty) parts.add(duration);
    return parts.join(' · ');
  }

  String _taskTime(PlannerTask task, DateTime start, DateTime? end) {
    if (end != null && end.isAfter(start)) return '${_time(start)} – ${_time(end)}';
    return _time(start);
  }

  bool _matches(String title, String? description, String? location, String query) {
    if (query.isEmpty) return true;
    return title.toLowerCase().contains(query) ||
        (description?.toLowerCase().contains(query) ?? false) ||
        (location?.toLowerCase().contains(query) ?? false);
  }

  String _time(DateTime value) => Formats.timeOfDay(value);

  bool _sameDay(DateTime a, DateTime b) => PlannerDates.sameDay(a, b);

  String _mealTitle(String? type) {
    if (type == null || type.isEmpty) return 'Meal';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  Color _kindColor(BlistraColors colors, _RowKind kind) => switch (kind) {
        _RowKind.task => colors.accentText,
        _RowKind.event => plannerEventColor(colors),
        _RowKind.medicine => colors.danger,
        _RowKind.habit => colors.data[2],
        _RowKind.meal => colors.warning,
        _RowKind.appointment => colors.data[0],
      };

  IconData _sourceIcon(_RowKind kind) => switch (kind) {
        _RowKind.task => Icons.task_alt_rounded,
        _RowKind.event => Icons.event_outlined,
        _RowKind.medicine => Icons.medication_outlined,
        _RowKind.habit => Icons.repeat_rounded,
        _RowKind.meal => Icons.restaurant_outlined,
        _RowKind.appointment => Icons.medical_services_outlined,
      };
}

/// 30 px round chevron used to step the selected day or week.
class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      iconSize: 20,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        foregroundColor: colors.text,
        disabledForegroundColor: colors.muted,
      ),
      icon: Icon(icon),
    );
  }
}

class _FilterSelection {
  const _FilterSelection({required this.kinds, required this.completed, required this.hideCompleted});

  final Set<_RowKind> kinds;
  final bool? completed;
  final bool hideCompleted;
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.selectedKinds, required this.completed, required this.hideCompleted});

  final Set<_RowKind> selectedKinds;
  final bool? completed;
  final bool hideCompleted;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final Set<_RowKind> _kinds;
  late bool? _completed;
  late bool _hideCompleted;

  @override
  void initState() {
    super.initState();
    _kinds = Set.of(widget.selectedKinds);
    _completed = widget.completed;
    _hideCompleted = widget.hideCompleted;
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    const kinds = [
      (_RowKind.task, 'Tasks', Icons.task_alt_rounded),
      (_RowKind.event, 'Events', Icons.event_outlined),
      (_RowKind.medicine, 'Medicine', Icons.medication_outlined),
      (_RowKind.habit, 'Habits', Icons.repeat_rounded),
      (_RowKind.meal, 'Meals', Icons.restaurant_outlined),
      (_RowKind.appointment, 'Appointments', Icons.medical_services_outlined),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter your schedule', style: BlistraText.serif(22, colors.text)),
              const SizedBox(height: 5),
              Text('Choose what appears on the Today tab.', style: TextStyle(fontSize: 12.5, color: colors.muted)),
              const FormCaption('Item type'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in kinds)
                    FilterChip(
                      selected: _kinds.contains(kind.$1),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _kinds.add(kind.$1);
                        } else {
                          _kinds.remove(kind.$1);
                        }
                      }),
                      avatar: Icon(kind.$3, size: 16),
                      label: Text(kind.$2),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const FormCaption('Completion'),
              GlassSegmented<bool?>(
                options: const [(null, 'All'), (false, 'Open'), (true, 'Completed')],
                selected: _completed,
                onChanged: (value) => setState(() => _completed = value),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text('Hide completed items', style: TextStyle(fontSize: 14, color: colors.text)),
                value: _hideCompleted,
                onChanged: (value) => setState(() => _hideCompleted = value),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _kinds.clear();
                      _completed = null;
                      _hideCompleted = false;
                    }),
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_FilterSelection(kinds: _kinds, completed: _completed, hideCompleted: _hideCompleted)),
                      child: const Text('Apply filters'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _RowKind { task, event, medicine, habit, meal, appointment }

class _Row {
  const _Row({
    required this.at,
    required this.title,
    required this.detail,
    required this.kind,
    required this.timed,
    required this.done,
    required this.timeLabel,
    this.cancelled = false,
    this.event,
    this.task,
    this.id,
    this.reminder = TaskReminderMode.none,
  });

  final DateTime at;
  final String title;

  /// List, location or source module, shown after the time.
  final String detail;
  final _RowKind kind;
  final bool timed;
  final bool done;
  final bool cancelled;
  final String timeLabel;
  final PlannerEvent? event;
  final PlannerTask? task;
  final String? id;
  final TaskReminderMode reminder;
}
