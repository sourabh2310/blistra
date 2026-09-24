import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
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
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../models/schedule_view.dart';
import '../models/task.dart';
import '../models/task_reminder_mode.dart';
import '../models/task_status.dart';
import '../planner_controller.dart';
import '../today_helpers.dart';
import '../widgets/status_views.dart';
import 'event_detail_screen.dart';
import 'task_detail_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
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
          await _refreshDashboard(scope);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _dateSelector(context, planner)),
            SliverToBoxAdapter(child: _scopeToggle(planner)),
            if (planner.scope == ScheduleScope.week)
              SliverToBoxAdapter(child: _weekStrip(context, planner)),
            SliverToBoxAdapter(child: _summary(planner, scope.dashboard.dashboard)),
            ..._timeline(context, planner, scope.dashboard.dashboard),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
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
    } catch (_) {
    }
  }

  Widget _dateSelector(BuildContext context, PlannerController planner) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final date = planner.selectedDate;
    final label = planner.scope == ScheduleScope.week
        ? 'Week of ${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}'
        : '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: planner.scope == ScheduleScope.week ? 'Previous week' : 'Previous day',
              onPressed: planner.scheduleLoading ? null : planner.previousDay,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickDate(context, planner),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            IconButton(
              tooltip: planner.scope == ScheduleScope.week ? 'Next week' : 'Next day',
              onPressed: planner.scheduleLoading ? null : planner.nextDay,
              icon: const Icon(Icons.chevron_right),
            ),
            TextButton(
              onPressed: planner.isTodaySelected ? null : planner.goToToday,
              child: const Text('Today'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, PlannerController planner) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: planner.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) await planner.selectDate(picked);
  }

  Widget _scopeToggle(PlannerController planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SegmentedButton<ScheduleScope>(
        segments: const [
          ButtonSegment(value: ScheduleScope.day, label: Text('Day'), icon: Icon(Icons.view_day_outlined)),
          ButtonSegment(value: ScheduleScope.week, label: Text('Week'), icon: Icon(Icons.view_week_outlined)),
        ],
        selected: {planner.scope},
        onSelectionChanged: (selection) => planner.setScope(selection.first),
      ),
    );
  }

  Widget _weekStrip(BuildContext context, PlannerController planner) {
    final start = planner.selectedDate;
    final selected = DateTime(start.year, start.month, start.day);
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final rows = _rows(planner, null);
    final counts = <DateTime, int>{};
    for (final row in rows.where((row) => !row.cancelled)) {
      final day = DateTime(row.at.year, row.at.month, row.at.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: AppCard(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            for (var index = 0; index < 7; index++)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final day = start.add(Duration(days: index));
                    final dayOnly = DateTime(day.year, day.month, day.day);
                    final isSelected = dayOnly == selected;
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      label: '${names[day.weekday - 1]} ${day.day}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          await planner.selectDate(day);
                          await planner.setScope(ScheduleScope.day);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            children: [
                              Text(names[day.weekday - 1], style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : null, fontSize: 11)),
                              Text('${day.day}', style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : null, fontWeight: FontWeight.w700)),
                              Text('${counts[dayOnly] ?? 0}', style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.onPrimary : null, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summary(PlannerController planner, DashboardResponse? dashboard) {
    final rows = _rows(planner, dashboard, includeCrossModule: false);
    final tasks = rows.where((row) => row.kind == _RowKind.task).length;
    final events = rows.where((row) => row.kind == _RowKind.event).length;
    final completed = rows.where((row) => row.done).length;
    if (!planner.isTodaySelected || (tasks == 0 && events == 0)) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AppCard(
        child: Row(
          children: [
            Expanded(child: _Metric(value: '$tasks', label: tasks == 1 ? 'task' : 'tasks', icon: Icons.task_alt)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _Metric(value: '$events', label: events == 1 ? 'event' : 'events', icon: Icons.event)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: _Metric(value: '$completed', label: 'completed', icon: Icons.check_circle_outline)),
          ],
        ),
      ),
    );
  }

  List<Widget> _timeline(BuildContext context, PlannerController planner, DashboardResponse? dashboard) {
    if ((planner.scheduleLoading || planner.loading) && planner.schedule == null) {
      return const [SliverToBoxAdapter(child: SkeletonLoader(rows: 5, rowHeight: 72))];
    }
    if (planner.scheduleError != null && planner.schedule == null) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: ErrorRetry(
            message: "Couldn't load your schedule.",
            onRetry: planner.loadSchedule,
          ),
        ),
      ];
    }
    final rows = _rows(planner, dashboard).where((row) => !row.cancelled).toList();
    if (rows.isEmpty) return [SliverToBoxAdapter(child: _emptyState(context, planner))];
    if (planner.scope == ScheduleScope.week) {
      final sorted = List<_Row>.from(rows)..sort((a, b) => a.at.compareTo(b.at));
      return [
        _section('THIS WEEK'),
        SliverList.builder(
          itemCount: sorted.length,
          itemBuilder: (context, index) => _rowCard(
            context,
            sorted[index],
            showDay: index == 0 || !_sameDay(sorted[index - 1].at, sorted[index].at),
          ),
        ),
      ];
    }
    final overdue = rows.where((row) => row.kind == _RowKind.task && row.task!.overdue && !row.done).toList();
    final completed = rows.where((row) => row.done).toList();
    final active = rows.where((row) => !row.done && !overdue.contains(row)).toList();
    final timed = active.where((row) => row.timed).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final untimed = active.where((row) => !row.timed).toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return [
      if (overdue.isNotEmpty) ...[
        _section('OVERDUE', color: Theme.of(context).colorScheme.error),
        SliverList.builder(itemCount: overdue.length, itemBuilder: (context, index) => _rowCard(context, overdue[index])),
      ],
      if (timed.isNotEmpty) ...[
        _section(planner.isTodaySelected ? "TODAY'S SCHEDULE" : 'SCHEDULE'),
        SliverList.builder(itemCount: timed.length, itemBuilder: (context, index) => _rowCard(context, timed[index])),
      ],
      if (untimed.isNotEmpty) ...[
        _section(planner.isTodaySelected ? 'TODAY' : 'UNSCHEDULED'),
        SliverList.builder(itemCount: untimed.length, itemBuilder: (context, index) => _rowCard(context, untimed[index])),
      ],
      if (completed.isNotEmpty) ...[
        _section('COMPLETED'),
        SliverList.builder(itemCount: completed.length, itemBuilder: (context, index) => _rowCard(context, completed[index])),
      ],
    ];
  }

  Widget _section(String label, {Color? color}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
        child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      ),
    );
  }

  Widget _rowCard(BuildContext context, _Row row, {bool showDay = false}) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    if (showDay) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text('${_weekday(row.at.weekday)} ${row.at.day}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
      ));
    }
    children.add(AppCard(
      onTap: () => _openRow(context, row),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (row.timed)
            SizedBox(
              width: 62,
              child: Text(row.timeLabel, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            )
          else
            SizedBox(width: 62, child: Icon(Icons.schedule, color: theme.colorScheme.onSurfaceVariant)),
          if (row.timed) const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, decoration: row.done ? TextDecoration.lineThrough : null)),
                const SizedBox(height: AppSpacing.xs),
                Text(row.subtitle, style: theme.textTheme.bodySmall),
                if (row.reminder != TaskReminderMode.none) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(children: [const Icon(Icons.notifications_none, size: 15), const SizedBox(width: 4), Text(row.reminder.label)]),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          StatusChip(label: row.source, color: _sourceColor(context, row.kind), icon: _sourceIcon(row.kind)),
          if (row.done) ...[
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.check_circle, color: Colors.green),
          ],
        ],
      ),
    ));
    return Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
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

  Widget _emptyState(BuildContext context, PlannerController planner) {
    final today = planner.isTodaySelected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: AppCard(
        child: Column(
          children: [
            Icon(today ? Icons.wb_sunny_outlined : Icons.event_available_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: AppSpacing.md),
            Text(today ? "You're clear for today." : 'Nothing is scheduled.', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(today ? 'No tasks or events scheduled.' : 'No tasks or events scheduled for this date.'),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: () async {
                final action = await showQuickAdd(context);
                if (action != null && context.mounted) await openQuickAddCreation(context, action);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
            TextButton(onPressed: () => planner.setScope(ScheduleScope.week), child: const Text('Plan your day')),
          ],
        ),
      ),
    );
  }

  List<_Row> _rows(PlannerController planner, DashboardResponse? dashboard, {bool includeCrossModule = true}) {
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
        subtitle: event.location?.isNotEmpty == true ? event.location! : 'Scheduled event',
        source: 'Event',
        kind: _RowKind.event,
        timed: true,
        done: event.status == EventStatus.completed,
        timeLabel: '${_time(start)}–${_time(end)}',
        endAt: end,
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
        subtitle: _taskSubtitle(task),
        source: 'Task',
        kind: _RowKind.task,
        timed: timed,
        done: task.status == TaskStatus.completed,
        timeLabel: timed ? _taskTime(task, start, end) : 'Anytime',
        endAt: end,
        task: task,
        reminder: task.reminderMode,
      ));
    }
    if (planner.isTodaySelected) {
      for (final task in planner.today?.overdueTasks ?? const <PlannerTask>[]) {
        if (seenTasks.contains(task.id) || !_matches(task.title, task.description, task.taskListName, query)) continue;
        final at = (task.dueAt ?? task.dueDate)?.toLocal() ?? planner.selectedDate;
        rows.add(_Row(at: at, title: task.title, subtitle: _taskSubtitle(task), source: 'Task', kind: _RowKind.task, timed: taskHasExplicitTime(task), done: false, timeLabel: 'Overdue', task: task, reminder: task.reminderMode));
      }
    }
    if (includeCrossModule && planner.isTodaySelected && dashboard != null) {
      final medicines = dashboard.medicines;
      if (medicines != null && !medicines.unavailable) {
        for (final dose in medicines.dosesToday) {
          final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(dose.medicineName, null, null, query)) continue;
          final status = dose.status.toUpperCase();
          rows.add(_Row(at: at, title: dose.medicineName, subtitle: 'Medicine · ${_time(at)}', source: 'Medicine', kind: _RowKind.medicine, timed: true, done: status == 'TAKEN', cancelled: status == 'SKIPPED', timeLabel: _time(at), id: dose.medicineId));
        }
      }
      final habits = dashboard.habits;
      if (habits != null && !habits.unavailable) {
        for (final habit in habits.todayHabits) {
          if (!_matches(habit.name, null, null, query)) continue;
          rows.add(_Row(at: planner.selectedDate, title: habit.name, subtitle: 'Habit · no time set', source: 'Habit', kind: _RowKind.habit, timed: false, done: habit.completedToday, timeLabel: 'Anytime', id: habit.id));
        }
      }
      final diet = dashboard.diet;
      if (diet != null && !diet.unavailable) {
        for (final meal in diet.meals) {
          final at = DateTime.tryParse(meal.consumedAt ?? '')?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(_mealTitle(meal.type), null, null, query)) continue;
          rows.add(_Row(at: at, title: _mealTitle(meal.type), subtitle: 'Meal · ${_time(at)}', source: 'Meal', kind: _RowKind.meal, timed: true, done: true, timeLabel: _time(at), id: meal.id));
        }
      }
      final health = dashboard.health;
      if (health != null && !health.unavailable) {
        for (final appointment in health.upcomingAppointments) {
          final at = DateTime.tryParse(appointment.scheduledAt)?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(appointment.title, null, null, query)) continue;
          final status = (appointment.status ?? '').toUpperCase();
          rows.add(_Row(at: at, title: appointment.title, subtitle: 'Appointment · ${_time(at)}', source: 'Appointment', kind: _RowKind.appointment, timed: true, done: status == 'COMPLETED', cancelled: status == 'CANCELLED', timeLabel: _time(at), id: appointment.id));
        }
      }
    }
    rows.sort((a, b) {
      if (a.timed != b.timed) return a.timed ? -1 : 1;
      return a.timed ? a.at.compareTo(b.at) : a.title.compareTo(b.title);
    });
    return rows;
  }

  String _taskSubtitle(PlannerTask task) {
    final parts = <String>[];
    if (task.taskListName?.isNotEmpty == true) parts.add(task.taskListName!);
    if (task.startAt != null && task.endAt != null) {
      final minutes = task.endAt!.difference(task.startAt!).inMinutes;
      if (minutes > 0) parts.add('${minutes ~/ 60}h ${minutes.remainder(60)}m');
    }
    if (task.overdue && task.status.isActive) parts.add('Overdue');
    return parts.isEmpty ? 'Task · no time set' : parts.join(' · ');
  }

  String _taskTime(PlannerTask task, DateTime start, DateTime? end) {
    if (end != null && end!.isAfter(start)) return '${_time(start)}–${_time(end.toLocal())}';
    return _time(start);
  }

  bool _matches(String title, String? description, String? location, String query) {
    if (query.isEmpty) return true;
    return title.toLowerCase().contains(query) ||
        (description?.toLowerCase().contains(query) ?? false) ||
        (location?.toLowerCase().contains(query) ?? false);
  }

  String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _weekday(int weekday) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][weekday - 1];

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _mealTitle(String? type) {
    if (type == null || type.isEmpty) return 'Meal';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  Color _sourceColor(BuildContext context, _RowKind kind) => switch (kind) {
        _RowKind.task => Theme.of(context).colorScheme.primary,
        _RowKind.event => const Color(0xFFB54708),
        _RowKind.medicine => const Color(0xFF2E7CC4),
        _RowKind.habit => const Color(0xFF7C3AED),
        _RowKind.meal => const Color(0xFF3E8E41),
        _RowKind.appointment => const Color(0xFFB54708),
      };

  IconData _sourceIcon(_RowKind kind) => switch (kind) {
        _RowKind.task => Icons.task_alt,
        _RowKind.event => Icons.event,
        _RowKind.medicine => Icons.medication_outlined,
        _RowKind.habit => Icons.repeat,
        _RowKind.meal => Icons.restaurant_outlined,
        _RowKind.appointment => Icons.medical_services_outlined,
      };
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label, required this.icon});

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: AppSpacing.xs),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

enum _RowKind { task, event, medicine, habit, meal, appointment }

class _Row {
  const _Row({
    required this.at,
    required this.title,
    required this.subtitle,
    required this.source,
    required this.kind,
    required this.timed,
    required this.done,
    required this.timeLabel,
    this.cancelled = false,
    this.endAt,
    this.event,
    this.task,
    this.id,
    this.reminder = TaskReminderMode.none,
  });

  final DateTime at;
  final String title;
  final String subtitle;
  final String source;
  final _RowKind kind;
  final bool timed;
  final bool done;
  final bool cancelled;
  final String timeLabel;
  final DateTime? endAt;
  final PlannerEvent? event;
  final PlannerTask? task;
  final String? id;
  final TaskReminderMode reminder;
}
