import 'package:flutter/material.dart';

import '../../../features/app_scope.dart';
import '../../dashboard/models/dashboard_response.dart';
import '../models/event_status.dart';
import '../models/planner_event.dart';
import '../models/schedule_view.dart';
import '../models/task.dart';
import '../planner_controller.dart';
import '../today_helpers.dart';
import '../widgets/status_views.dart';
import 'event_form_screen.dart';
import 'task_form_screen.dart';

/// Today tab: the Planner orchestration layer for the current day.
///
/// Content-only widget — the single Planner header and pill switcher live in
/// [HomeScreen]. No nested Scaffold/AppBar/bottom navigation here, and no
/// floating + button (inline CTAs only, so nothing hides behind the global
/// bottom navigation).
///
/// Planner-owned rows (tasks/events) are actionable. Domain-owned rows
/// (medicine/habit/meal/appointment) are referenced live from the Dashboard
/// payload and never duplicated — tapping them explains ownership.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  static const _teal = Color(0xFF0C6B6B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final planner = AppScope.of(context).planner;
      if (planner.schedule == null && !planner.scheduleLoading) {
        planner.loadSchedule();
      }
      if (planner.today == null) {
        planner.loadToday();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final planner = scope.planner;
    return ListenableBuilder(
      listenable: Listenable.merge([planner, scope.dashboard]),
      builder: (context, _) => RefreshIndicator(
        color: _teal,
        onRefresh: () => _refresh(planner, scope),
        child: _scrollBody(context, planner, scope),
      ),
    );
  }

  Widget _scrollBody(
      BuildContext context, PlannerController planner, AppScope scope) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _dateSelector(context, planner)),
        SliverToBoxAdapter(child: _scopeToggle(planner)),
        if (planner.scope == ScheduleScope.week)
          SliverToBoxAdapter(child: _weekOverview(planner)),
        SliverToBoxAdapter(child: _summaryCard(planner, scope)),
        _timelineSliver(context, planner, scope),
        // Clearance for the global bottom navigation — no FAB overlap.
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  /// Dashboard refresh is best-effort: it must never turn a successful
  /// Planner mutation/load into a visible failure.
  Future<void> _refresh(PlannerController planner, AppScope scope) async {
    await planner.loadSchedule();
    await planner.loadToday();
    try {
      await scope.dashboard.refresh(
        date: DateTime.now(),
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } catch (_) {
      // Planner data already loaded; dashboard staleness is non-fatal.
    }
  }

  Future<void> _refreshDashboardQuiet(AppScope scope) async {
    try {
      await scope.dashboard.refresh(
        date: DateTime.now(),
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } catch (_) {
      // Non-blocking by design (see _refresh).
    }
  }

  // ── Date navigation: < Thu 24 Sep > + Today ──────────────────────
  Widget _dateSelector(BuildContext context, PlannerController planner) {
    final d = planner.selectedDate;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final label = planner.scope == ScheduleScope.week
        ? 'Week of ${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}'
        : '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0EDE8)),
        ),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous',
              icon: const Icon(Icons.chevron_left),
              onPressed: planner.scheduleLoading
                  ? null
                  : () => planner.previousDay(),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(context, planner),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800)),
                      if (!planner.isTodaySelected)
                        const Text('Tap Today to jump back',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF667085))),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Next',
              icon: const Icon(Icons.chevron_right),
              onPressed:
                  planner.scheduleLoading ? null : () => planner.nextDay(),
            ),
            TextButton(
              onPressed:
                  planner.isTodaySelected && planner.scope == ScheduleScope.day
                      ? null
                      : () => planner.goToToday(),
              child: const Text('Today'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scopeToggle(PlannerController planner) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SegmentedButton<ScheduleScope>(
        segments: const [
          ButtonSegment(
              value: ScheduleScope.day,
              label: Text('Day'),
              icon: Icon(Icons.view_day_outlined)),
          ButtonSegment(
              value: ScheduleScope.week,
              label: Text('Week'),
              icon: Icon(Icons.view_week_outlined)),
        ],
        selected: {planner.scope},
        onSelectionChanged: (s) => planner.setScope(s.first),
      ),
    );
  }

  // ── Week overview: per-day counts, tap opens that day's schedule ──
  Widget _weekOverview(PlannerController planner) {
    final rows = _timelineItems(planner, null, weekOnly: true);
    final entries = [
      for (final r in rows)
        TimelineEntry(
            at: r.at, title: r.title, source: r.chip, done: r.done),
    ];
    final counts = countByDay(entries);
    final start = planner.selectedDate;
    final days = [for (int i = 0; i < 7; i++) start.add(Duration(days: i))];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const names = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF0EDE8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This week',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => _openWeekDay(planner, d),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: d == today ? _teal : const Color(0xFFF7F5F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(names[d.weekday - 1],
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: d == today
                                          ? Colors.white70
                                          : const Color(0xFF667085))),
                              Text('${d.day}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: d == today
                                          ? Colors.white
                                          : const Color(0xFF101828))),
                              const SizedBox(height: 2),
                              Text(
                                '${counts[DateTime(d.year, d.month, d.day)] ?? 0}',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: d == today
                                        ? Colors.white
                                        : const Color(0xFF0C6B6B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Select a day to see its schedule.',
                style: TextStyle(fontSize: 12, color: Color(0xFF667085))),
          ],
        ),
      ),
    );
  }

  Future<void> _openWeekDay(
      PlannerController planner, DateTime day) async {
    await planner.selectDate(day);
    await planner.setScope(ScheduleScope.day);
  }

  // ── Today summary: factual totals + progress ─────────────────────
  Widget _summaryCard(PlannerController planner, AppScope scope) {
    // Summary reflects the visible timeline (planner + aggregated domains).
    final rows = _timelineItems(planner, scope.dashboard.dashboard);
    final summary = computeTodaySummary([
      for (final r in rows)
        TimelineEntry(
            at: r.at,
            title: r.title,
            source: r.chip,
            done: r.done,
            cancelled: r.cancelled),
    ]);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E6E6E), Color(0xFF0A4E4E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              rows.isEmpty
                  ? 'No plans yet'
                  : '${summary.total} item${summary.total == 1 ? '' : 's'} · '
                      '${summary.completed} completed · '
                      '${summary.remaining} remaining',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: summary.fraction,
                      minHeight: 10,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFF5EEAD4)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  rows.isEmpty
                      ? '—'
                      : '${(summary.fraction * 100).round()}%',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Timeline body with sections ──────────────────────────────────
  Widget _timelineSliver(
      BuildContext context, PlannerController planner, AppScope scope) {
    if (planner.scheduleLoading && planner.schedule == null) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(color: _teal)),
      );
    }
    if (planner.scheduleError != null && planner.schedule == null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: ErrorRetry(
            message: planner.scheduleError!,
            onRetry: () => planner.loadSchedule()),
      );
    }
    final rows = _timelineItems(planner, scope.dashboard.dashboard);
    if (rows.isEmpty) {
      return SliverToBoxAdapter(child: _emptyState(context, planner, scope));
    }
    final now = DateTime.now();
    final sections = sectionEntries(
      [
        for (final r in rows)
          TimelineEntry(
              at: r.at,
              title: r.title,
              source: r.chip,
              done: r.done,
              cancelled: r.cancelled),
      ],
      now,
    );
    final byTime = <_Row, DateTime>{for (final r in rows) r: r.at};
    List<_Row> order(List<TimelineEntry> section) {
      final out = <_Row>[];
      for (final e in section) {
        for (final r in rows) {
          if (r.title == e.title &&
              r.at == e.at &&
              r.chip == e.source &&
              !out.contains(r)) {
            out.add(r);
            break;
          }
        }
      }
      out.sort((a, b) => byTime[a]!.compareTo(byTime[b]!));
      return out;
    }

    final children = <Widget>[];
    if (planner.scope == ScheduleScope.week) {
      children.add(_weekList(context, planner, scope, rows));
    } else {
      if (order(sections.overdue).isNotEmpty) {
        children.add(_sectionHeader('Overdue', const Color(0xFFB42318)));
        for (final r in order(sections.overdue)) {
          children.add(_timelineRow(context, planner, scope, r));
        }
      }
      if (order(sections.upNext).isNotEmpty) {
        children.add(_sectionHeader('Up next', _teal));
        for (final r in order(sections.upNext)) {
          children.add(_timelineRow(context, planner, scope, r));
        }
      }
      if (order(sections.laterToday).isNotEmpty) {
        children.add(_sectionHeader('Later today', const Color(0xFF3E4A5A)));
        for (final r in order(sections.laterToday)) {
          children.add(_timelineRow(context, planner, scope, r));
        }
      }
      if (order(sections.completed).isNotEmpty) {
        children.add(_sectionHeader('Completed', const Color(0xFF667085)));
        for (final r in order(sections.completed)) {
          children.add(_timelineRow(context, planner, scope, r));
        }
      }
    }
    return SliverList(
      delegate: SliverChildListDelegate(children),
    );
  }

  Widget _sectionHeader(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 2),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: color)),
    );
  }

  Widget _weekList(BuildContext context, PlannerController planner,
      AppScope scope, List<_Row> rows) {
    final sorted = List<_Row>.from(rows)
      ..sort((a, b) => a.at.compareTo(b.at));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < sorted.length; i++)
          _timelineRow(
            context,
            planner,
            scope,
            sorted[i],
            showDayHeader: i == 0 || !_sameDay(sorted[i - 1].at, sorted[i].at),
          ),
      ],
    );
  }

  Widget _emptyState(
      BuildContext context, PlannerController planner, AppScope scope) {
    final isToday = planner.isTodaySelected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFF0EDE8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available,
                  size: 30, color: _teal),
            ),
            const SizedBox(height: 12),
            const Text('No plans yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              isToday
                  ? 'Add a task or event, or schedule something from your modules.'
                  : 'Nothing scheduled for this date.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openTaskForm(planner, scope),
                    icon: const Icon(Icons.add_task),
                    label: const Text('Add task'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _teal),
                    onPressed: () => _openEventForm(planner, scope),
                    icon: const Icon(Icons.add),
                    label: const Text('Add event'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<_Row> _timelineItems(
      PlannerController planner, DashboardResponse? dashboard,
      {bool weekOnly = false}) {
    final rows = <_Row>[];
    for (final e in planner.scheduleEventsOrdered) {
      rows.add(_Row(
        at: e.startAt.toLocal(),
        end: e.endAt.toLocal(),
        title: e.title,
        subtitle:
            '${_hhmm(e.startAt.toLocal())} – ${_hhmm(e.endAt.toLocal())}${e.location?.isNotEmpty == true ? ' · ${e.location}' : ''}',
        chip: 'Event',
        kind: _Kind.plannerEvent,
        event: e,
        done: e.status == EventStatus.completed,
        cancelled: e.status == EventStatus.cancelled,
      ));
    }
    for (final t in planner.scheduleTasksOrdered) {
      final at = (t.dueAt ?? t.dueDate)?.toLocal() ??
          planner.selectedDate.add(const Duration(hours: 9));
      rows.add(_Row(
        at: at,
        end: null,
        title: t.title,
        subtitle:
            'Due${t.dueTime != null ? ' ${_hhmm(at)}' : ''}${t.taskListName?.isNotEmpty == true ? ' · ${t.taskListName}' : ''}',
        chip: 'Task',
        kind: _Kind.task,
        task: t,
        done: !t.status.isActive &&
            t.status.name.toUpperCase() == 'COMPLETED',
        cancelled: t.status.name.toUpperCase() == 'CANCELLED',
      ));
    }
    // Cross-module rows: selected-today only, referenced live from Dashboard.
    if (!weekOnly && planner.isTodaySelected && dashboard != null) {
      final meds = dashboard.medicines;
      if (meds != null && !meds.unavailable) {
        for (final d in meds.dosesToday) {
          if (!_matchesQuery(
              '${d.medicineName} medicine', planner.searchQuery)) {
            continue;
          }
          final at = DateTime.tryParse(d.scheduledAt)?.toLocal();
          if (at == null) continue;
          final s = d.status.toUpperCase();
          rows.add(_Row(
            at: at,
            end: null,
            title: d.medicineName,
            subtitle: 'Medicine · ${_hhmm(at)}',
            chip: 'Medicine',
            kind: _Kind.medicine,
            meta: d.medicineId,
            done: s == 'TAKEN',
            cancelled: s == 'CANCELLED' || s == 'SKIPPED',
          ));
        }
      }
      final habits = dashboard.habits;
      if (habits != null && !habits.unavailable) {
        for (final h in habits.todayHabits) {
          if (!_matchesQuery('${h.name} habit', planner.searchQuery)) {
            continue;
          }
          rows.add(_Row(
            at: planner.selectedDate.add(const Duration(hours: 7)),
            end: null,
            title: h.name,
            subtitle: 'Habit · today',
            chip: 'Habit',
            kind: _Kind.habit,
            done: h.completedToday,
            cancelled: false,
          ));
        }
      }
      final diet = dashboard.diet;
      if (diet != null && !diet.unavailable) {
        for (final m in diet.meals) {
          if (m.consumedAt == null) continue;
          final at = DateTime.tryParse(m.consumedAt!)?.toLocal();
          if (at == null) continue;
          if (!_matchesQuery(
              '${_mealTitle(m.type)} meal', planner.searchQuery)) {
            continue;
          }
          rows.add(_Row(
            at: at,
            end: null,
            title: _mealTitle(m.type),
            subtitle: 'Meal · ${_hhmm(at)}',
            chip: 'Meal',
            kind: _Kind.meal,
            done: true,
            cancelled: false,
          ));
        }
      }
      final health = dashboard.health;
      if (health != null && !health.unavailable) {
        for (final a in health.upcomingAppointments) {
          final at = DateTime.tryParse(a.scheduledAt)?.toLocal();
          if (at == null || !_sameDay(at, DateTime.now())) continue;
          if (!_matchesQuery(
              '${a.title} appointment', planner.searchQuery)) {
            continue;
          }
          final s = (a.status ?? '').toUpperCase();
          rows.add(_Row(
            at: at,
            end: null,
            title: a.title,
            subtitle: 'Appointment · ${_hhmm(at)}',
            chip: 'Appointment',
            kind: _Kind.appointment,
            done: s == 'COMPLETED',
            cancelled: s == 'CANCELLED',
          ));
        }
      }
    }
    rows.sort((a, b) => a.at.compareTo(b.at));
    return rows;
  }

  bool _matchesQuery(String haystack, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return haystack.toLowerCase().contains(q);
  }

  String _mealTitle(String? type) {
    if (type == null || type.isEmpty) return 'Meal';
    final lower = type.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  String _hhmm(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  Widget _timelineRow(BuildContext context, PlannerController planner,
      AppScope scope, _Row row,
      {bool showDayHeader = false}) {
    final timeLabel = _hhmm(row.at);
    final chip = _SourceChip(source: row.chip);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDayHeader)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                '${['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][row.at.weekday - 1]} ${row.at.day}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: _teal),
              ),
            ),
          InkWell(
            onTap: () => _onRowTap(context, planner, scope, row),
            borderRadius: BorderRadius.circular(16),
            child: Opacity(
              opacity: row.done ? 0.72 : 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF0EDE8)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: Text(timeLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, color: _teal)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(row.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        decoration: row.cancelled
                                            ? TextDecoration.lineThrough
                                            : null,
                                        color: row.cancelled
                                            ? const Color(0xFF98A2B3)
                                            : const Color(0xFF101828))),
                              ),
                              const SizedBox(width: 6),
                              chip,
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(row.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667085))),
                        ],
                      ),
                    ),
                    if (row.kind == _Kind.plannerEvent)
                      IconButton(
                        tooltip: row.done ? 'Reopen' : 'Complete',
                        icon: Icon(
                            row.done
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: row.done
                                ? Colors.green
                                : const Color(0xFF98A2B3)),
                        onPressed: () =>
                            _toggleEvent(context, planner, scope, row.event!),
                      )
                    else if (row.kind == _Kind.task)
                      IconButton(
                        tooltip: 'Toggle',
                        icon: Icon(
                            row.done
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: row.done
                                ? Colors.green
                                : const Color(0xFF98A2B3)),
                        onPressed: () =>
                            _toggleTask(context, planner, scope, row.task!),
                      )
                    else
                      const Icon(Icons.chevron_right,
                          color: Color(0xFF98A2B3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onRowTap(BuildContext context, PlannerController planner,
      AppScope scope, _Row row) async {
    switch (row.kind) {
      case _Kind.plannerEvent:
        _showEventDetails(context, planner, scope, row.event!);
      case _Kind.task:
        _showTaskDetails(context, planner, scope, row.task!);
      case _Kind.medicine:
      case _Kind.habit:
      case _Kind.meal:
      case _Kind.appointment:
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${row.title} is managed in its own module — Planner only references it.')),
        );
    }
  }

  Future<void> _toggleEvent(BuildContext context, PlannerController planner,
      AppScope scope, PlannerEvent event) async {
    try {
      if (event.status == EventStatus.completed) {
        await planner.reopenEvent(event.id);
      } else {
        await planner.completeEvent(event.id);
      }
      await _refreshDashboardQuiet(scope);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(planner.error ?? 'Update failed')),
        );
      }
    }
  }

  Future<void> _toggleTask(BuildContext context, PlannerController planner,
      AppScope scope, PlannerTask task) async {
    try {
      if (task.status.isActive) {
        await planner.completeTask(task.id);
      } else {
        await planner.reopenTask(task.id);
      }
      await planner.loadSchedule();
      await _refreshDashboardQuiet(scope);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(planner.error ?? 'Update failed')),
        );
      }
    }
  }

  Future<void> loadScheduleAndHome(
      PlannerController planner, AppScope scope) async {
    await planner.loadSchedule();
    await _refreshDashboardQuiet(scope);
  }

  Future<void> _showTaskDetails(BuildContext context,
      PlannerController planner, AppScope scope, PlannerTask task) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.title,
                        style: const TextStyle(
                            fontSize: 19, fontWeight: FontWeight.w800)),
                  ),
                  _SourceChip(source: 'Task'),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'An action to complete${task.taskListName?.isNotEmpty == true ? ' · ${task.taskListName}' : ''}',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) =>
                                  TaskFormScreen(planner: planner, task: task)),
                        );
                        await loadScheduleAndHome(planner, scope);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _teal),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _toggleTask(context, planner, scope, task);
                      },
                      icon: Icon(task.status.isActive
                          ? Icons.check
                          : Icons.replay),
                      label: Text(
                          task.status.isActive ? 'Complete' : 'Reopen'),
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

  // Event details: view first — opening never completes the event.
  Future<void> _showEventDetails(BuildContext context,
      PlannerController planner, AppScope scope, PlannerEvent event) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                      color: const Color(0xFFE4E7EC),
                      borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(event.title,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                  ),
                  _statusChip(event.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                  '${_hhmm(event.startAt.toLocal())} – ${_hhmm(event.endAt.toLocal())}',
                  style: const TextStyle(
                      color: _teal, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              const Text('Scheduled commitment at a fixed time.',
                  style: TextStyle(
                      fontSize: 12, color: Color(0xFF667085))),
              if (event.location?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('📍 ${event.location}',
                      style:
                          const TextStyle(color: Color(0xFF667085))),
                ),
              if (event.description?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(event.description!),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                              builder: (_) => EventFormScreen(
                                  planner: planner, event: event)),
                        );
                        await loadScheduleAndHome(planner, scope);
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _teal),
                      onPressed: event.status == EventStatus.cancelled
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _toggleEvent(
                                  context, planner, scope, event);
                            },
                      icon: Icon(event.status == EventStatus.completed
                          ? Icons.replay
                          : Icons.check),
                      label: Text(event.status == EventStatus.completed
                          ? 'Reopen'
                          : 'Complete'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (event.status == EventStatus.scheduled)
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);
                          await planner.cancelEvent(event.id);
                          await loadScheduleAndHome(planner, scope);
                        },
                        icon: const Icon(Icons.block),
                        label: const Text('Cancel event'),
                      ),
                    ),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFB42318)),
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text('Delete "${event.title}"?'),
                            content: const Text(
                                'This cannot be undone.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(c, false),
                                  child: const Text('Keep')),
                              FilledButton(
                                  style: FilledButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFB42318)),
                                  onPressed: () =>
                                      Navigator.pop(c, true),
                                  child: const Text('Delete')),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          if (context.mounted) Navigator.pop(context);
                          await planner.deleteEvent(event.id);
                          await loadScheduleAndHome(planner, scope);
                        }
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
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

  Widget _statusChip(EventStatus status) {
    final label = switch (status) {
      EventStatus.completed => 'Completed',
      EventStatus.cancelled => 'Cancelled',
      EventStatus.scheduled => 'Scheduled',
    };
    final bg = switch (status) {
      EventStatus.completed => const Color(0xFFE6F6F3),
      EventStatus.cancelled => const Color(0xFFFDECEC),
      EventStatus.scheduled => const Color(0xFFEAF2F2),
    };
    final fg = switch (status) {
      EventStatus.completed => _teal,
      EventStatus.cancelled => const Color(0xFFB42318),
      EventStatus.scheduled => _teal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Future<void> _pickDate(
      BuildContext context, PlannerController planner) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: planner.selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      await planner.selectDate(picked);
    }
  }

  Future<void> _openEventForm(
      PlannerController planner, AppScope scope) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EventFormScreen(planner: planner),
      ),
    );
    if (saved == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      await loadScheduleAndHome(planner, scope);
      messenger.showSnackBar(
        const SnackBar(content: Text('Event created')),
      );
    }
  }

  Future<void> _openTaskForm(
      PlannerController planner, AppScope scope) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskFormScreen(planner: planner),
      ),
    );
    if (saved == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      await loadScheduleAndHome(planner, scope);
      messenger.showSnackBar(
        const SnackBar(content: Text('Task created')),
      );
    }
  }
}

/// Subtle source label: which domain owns this row.
class _SourceChip extends StatelessWidget {
  const _SourceChip({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (source) {
      'Habit' => (const Color(0xFFF1EAFE), const Color(0xFF7C3AED)),
      'Medicine' => (const Color(0xFFEAF5FF), const Color(0xFF2E7CC4)),
      'Task' => (const Color(0xFFE6F6F3), const Color(0xFF0C6B6B)),
      'Event' => (const Color(0xFFFFF1E0), const Color(0xFFB54708)),
      'Meal' => (const Color(0xFFEDF9E8), const Color(0xFF3E8E41)),
      _ => (const Color(0xFFF1F4F6), const Color(0xFF3E4A5A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(source,
          style: TextStyle(
              color: fg, fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

enum _Kind { plannerEvent, task, medicine, habit, meal, appointment }

class _Row {
  _Row({
    required this.at,
    required this.end,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.kind,
    required this.done,
    required this.cancelled,
    this.event,
    this.task,
    this.meta,
  });

  final DateTime at;
  final DateTime? end;
  final String title;
  final String subtitle;
  final String chip;
  final _Kind kind;
  final bool done;
  final bool cancelled;
  final PlannerEvent? event;
  final PlannerTask? task;
  final String? meta;
}
