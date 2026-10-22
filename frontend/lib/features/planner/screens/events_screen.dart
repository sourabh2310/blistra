import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../features/app_scope.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../models/task.dart';
import '../models/task_status.dart';
import '../planner_controller.dart';
import '../today_helpers.dart';
import '../widgets/event_card.dart';
import '../widgets/planner_parts.dart';
import '../widgets/status_views.dart';
import 'event_detail_screen.dart';
import 'event_form_screen.dart';
import 'tasks_screen.dart';

/// Planner "Calendar" tab: a month grid with dots for events and dated
/// tasks, the chosen day's items, then every event.
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  late DateTime _month;
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _day = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final planner = AppScope.of(context).planner;
    return ListenableBuilder(
      listenable: planner,
      builder: (context, _) => RefreshIndicator(
        onRefresh: () => Future.wait([planner.loadEvents(), planner.loadTasks()]),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
          children: _body(context, planner),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, PlannerController planner) {
    if (planner.loading && planner.events.isEmpty) {
      return const [SkeletonLoader(rows: 5, rowHeight: 64)];
    }
    if (planner.error != null && planner.events.isEmpty) {
      return [
        ErrorRetry(
          message: "Couldn't load your events.",
          onRetry: planner.loadEvents,
        ),
      ];
    }
    final events = _visibleEvents(planner);
    final tasks = _datedTasks(planner);
    final dayEvents = events.where((event) => PlannerDates.sameDay(event.startAt.toLocal(), _day)).toList();
    final dayTasks = tasks.where((task) => PlannerDates.sameDay(taskScheduleDay(task)!, _day)).toList();
    return [
      PagePad(_monthCard(context, events, tasks)),
      const SizedBox(height: 22),
      SectionHeader(title: PlannerDates.relative(_day)),
      PagePad(
        dayEvents.isEmpty && dayTasks.isEmpty
            ? const EmptyCard(message: 'Nothing scheduled on this day.')
            : GlassList(children: [
                for (final event in dayEvents) eventRow(context, planner, event),
                for (final task in dayTasks) taskRow(context, planner, task),
              ]),
      ),
      const SizedBox(height: 22),
      SectionHeader(title: 'All events', actionLabel: '${events.length}'),
      PagePad(
        events.isEmpty
            ? EmptyCard(
                message: planner.searchQuery.trim().isNotEmpty
                    ? 'No matching events. Try a different Planner search.'
                    : 'No events yet. Use the global Add button to schedule an appointment or commitment.',
              )
            : GlassList(children: [for (final event in events) eventRow(context, planner, event)]),
      ),
    ];
  }

  Widget _monthCard(BuildContext context, List<PlannerEvent> events, List<PlannerTask> tasks) {
    final colors = BlistraColors.resolve(context);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month).weekday - 1;
    final cells = ((leading + days + 6) ~/ 7) * 7;
    final marks = <DateTime, List<Color>>{};
    for (final event in events) {
      marks.putIfAbsent(PlannerDates.dateOnly(event.startAt.toLocal()), () => []).add(plannerEventColor(colors));
    }
    for (final task in tasks) {
      marks.putIfAbsent(taskScheduleDay(task)!, () => []).add(task.overdue && task.status.isActive ? colors.danger : colors.accentText);
    }
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Previous month',
                visualDensity: VisualDensity.compact,
                onPressed: () => _moveMonth(-1),
                icon: Icon(Icons.chevron_left_rounded, color: colors.text),
              ),
              Expanded(
                child: Text(
                  PlannerDates.month(_month),
                  textAlign: TextAlign.center,
                  style: BlistraText.serif(17, colors.text),
                ),
              ),
              IconButton(
                tooltip: 'Next month',
                visualDensity: VisualDensity.compact,
                onPressed: () => _moveMonth(1),
                icon: Icon(Icons.chevron_right_rounded, color: colors.text),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(label, textAlign: TextAlign.center, style: BlistraText.caption(colors.muted)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var week = 0; week < cells; week += 7)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(child: _dayCell(context, week + weekday - leading + 1, days, marks)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(BuildContext context, int dayNumber, int days, Map<DateTime, List<Color>> marks) {
    if (dayNumber < 1 || dayNumber > days) return const SizedBox(height: 46);
    final colors = BlistraColors.resolve(context);
    final date = DateTime(_month.year, _month.month, dayNumber);
    final selected = PlannerDates.sameDay(date, _day);
    final today = PlannerDates.sameDay(date, DateTime.now());
    final dots = marks[date] ?? const <Color>[];
    return Semantics(
      button: true,
      selected: selected,
      label: '${PlannerDates.short(date)}, ${dots.length} ${dots.length == 1 ? 'item' : 'items'}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _day = date),
        child: Container(
          height: 46,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: selected ? colors.accentText : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: today && !selected ? Border.all(color: colors.accentText.withValues(alpha: 0.6)) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$dayNumber',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected || today ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: BlistraText.tabular,
                  color: selected ? colors.onAccent : colors.text,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final color in dots.take(3))
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: selected ? colors.onAccent : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final last = DateTime(_month.year, _month.month + 1, 0).day;
      _day = DateTime(_month.year, _month.month, _day.day.clamp(1, last));
    });
  }

  List<PlannerEvent> _visibleEvents(PlannerController planner) {
    final query = planner.searchQuery.trim().toLowerCase();
    final events = List<PlannerEvent>.from(planner.events)
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (query.isEmpty) return events;
    return events.where((event) {
      return event.title.toLowerCase().contains(query) ||
          (event.description?.toLowerCase().contains(query) ?? false) ||
          (event.location?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  List<PlannerTask> _datedTasks(PlannerController planner) {
    final query = planner.searchQuery.trim().toLowerCase();
    return planner.tasks.where((task) {
      if (task.status == TaskStatus.cancelled || taskScheduleDay(task) == null) return false;
      if (query.isEmpty) return true;
      return task.title.toLowerCase().contains(query) ||
          (task.description?.toLowerCase().contains(query) ?? false);
    }).toList();
  }
}

/// An event row with open, edit, complete/reopen, cancel and delete wired
/// to [planner].
Widget eventRow(BuildContext context, PlannerController planner, PlannerEvent event) {
  return EventCard(
    event: event,
    onOpen: () => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EventDetailScreen(planner: planner, eventId: event.id)),
    ),
    onEdit: () => _openEventForm(context, planner, event: event),
    onDelete: () => _confirmEventDelete(context, () => planner.deleteEvent(event.id)),
    onToggleComplete: () => _runEventAction(
      context,
      () => event.status == EventStatus.completed || event.status == EventStatus.cancelled
          ? planner.reopenEvent(event.id)
          : planner.completeEvent(event.id),
    ),
    onCancel: event.status == EventStatus.scheduled
        ? () => _runEventAction(context, () => planner.cancelEvent(event.id))
        : null,
  );
}

Future<void> _openEventForm(BuildContext context, PlannerController planner, {PlannerEvent? event}) async {
  final saved = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => EventFormScreen(planner: planner, event: event)),
  );
  if (saved == true && context.mounted) {
    showAppMessage(context, event == null ? 'Event created' : 'Event updated');
  }
}

Future<void> _confirmEventDelete(BuildContext context, Future<void> Function() action) async {
  final confirmed = await confirmAction(
    context,
    title: 'Delete this event?',
    message: 'This cannot be undone.',
  );
  if (confirmed && context.mounted) await _runEventAction(context, action);
}

Future<void> _runEventAction(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) showAppMessage(context, "Couldn't update this event.", error: true);
  }
}
