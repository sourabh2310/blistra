import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  late DateTime _dayAnchor;
  bool _dayAnchorInitialized = false;
  _PlannerViewMode _viewMode = _PlannerViewMode.day;
  final Set<_RowKind> _kinds = {};
  bool? _completedFilter;
  bool _hideCompleted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dayAnchorInitialized) {
      _dayAnchor = AppScope.of(context).planner.selectedDate;
      _dayAnchorInitialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final planner = scope.planner;
    return ListenableBuilder(
      listenable: Listenable.merge([planner, scope.dashboard]),
      builder: (context, _) => RefreshIndicator(
        onRefresh: () async {
          if (_viewMode == _PlannerViewMode.month || _viewMode == _PlannerViewMode.agenda) {
            if (planner.scope != ScheduleScope.week) await planner.setScope(ScheduleScope.week);
          }
          await planner.loadSchedule();
          await planner.loadToday();
          await _refreshDashboard(scope);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _dateControls(context, planner)),
            SliverToBoxAdapter(child: _viewControls(context, planner)),
            if (_viewMode == _PlannerViewMode.month)
              ..._monthView(context, planner, scope.dashboard.dashboard)
            else if (_viewMode == _PlannerViewMode.agenda)
              ..._agendaView(context, planner, scope.dashboard.dashboard)
            else
              ..._timelineView(context, planner, scope.dashboard.dashboard),
            const SliverToBoxAdapter(child: SizedBox(height: 28)),
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
    } catch (_) {}
  }

  Widget _dateControls(BuildContext context, PlannerController planner) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: planner.isTodaySelected && _viewMode == _PlannerViewMode.day
                    ? null
                    : _goToToday,
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF2EFE9),
                  foregroundColor: const Color(0xFF294D65),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Today'),
              ),
              const SizedBox(width: 2),
              IconButton(
                tooltip: _previousTooltip,
                onPressed: planner.scheduleLoading ? null : _previous,
                icon: const Icon(Icons.chevron_left, color: Color(0xFF294D65)),
              ),
              IconButton(
                tooltip: _nextTooltip,
                onPressed: planner.scheduleLoading ? null : _next,
                icon: const Icon(Icons.chevron_right, color: Color(0xFF294D65)),
              ),
            ],
          ),
        ),
        _weekStrip(context, planner),
      ],
    );
  }

  String get _previousTooltip => switch (_viewMode) {
        _PlannerViewMode.day => 'Previous day',
        _PlannerViewMode.week => 'Previous week',
        _PlannerViewMode.month => 'Previous month',
        _PlannerViewMode.agenda => 'Previous agenda window',
      };

  String get _nextTooltip => switch (_viewMode) {
        _PlannerViewMode.day => 'Next day',
        _PlannerViewMode.week => 'Next week',
        _PlannerViewMode.month => 'Next month',
        _PlannerViewMode.agenda => 'Next agenda window',
      };

  Future<void> _goToToday() async {
    final planner = AppScope.of(context).planner;
    setState(() => _viewMode = _PlannerViewMode.day);
    if (planner.scope != ScheduleScope.day) await planner.setScope(ScheduleScope.day);
    await planner.goToToday();
    _dayAnchor = planner.selectedDate;
  }

  Future<void> _previous() async {
    final planner = AppScope.of(context).planner;
    switch (_viewMode) {
      case _PlannerViewMode.day:
        await planner.previousDay();
        _dayAnchor = planner.selectedDate;
        return;
      case _PlannerViewMode.week:
        await planner.previousDay();
        return;
      case _PlannerViewMode.month:
        await _moveMonth(-1);
        return;
      case _PlannerViewMode.agenda:
        if (planner.scope == ScheduleScope.week) {
          await planner.selectDate(planner.selectedDate.subtract(const Duration(days: 7)));
        }
        return;
    }
  }

  Future<void> _next() async {
    final planner = AppScope.of(context).planner;
    switch (_viewMode) {
      case _PlannerViewMode.day:
        await planner.nextDay();
        _dayAnchor = planner.selectedDate;
        return;
      case _PlannerViewMode.week:
        await planner.nextDay();
        return;
      case _PlannerViewMode.month:
        await _moveMonth(1);
        return;
      case _PlannerViewMode.agenda:
        if (planner.scope == ScheduleScope.week) {
          await planner.selectDate(planner.selectedDate.add(const Duration(days: 7)));
        }
        return;
    }
  }

  Future<void> _moveMonth(int delta) async {
    final planner = AppScope.of(context).planner;
    final current = planner.selectedDate;
    final month = DateTime(current.year, current.month + delta);
    final day = current.day.clamp(1, DateTime(month.year, month.month + 1, 0).day).toInt();
    await planner.selectDate(DateTime(month.year, month.month, day));
  }

  Future<void> _chooseView(_PlannerViewMode mode, PlannerController planner) async {
    if (mode == _viewMode) return;
    setState(() => _viewMode = mode);
    if (mode == _PlannerViewMode.day) {
      if (planner.scope != ScheduleScope.day) await planner.setScope(ScheduleScope.day);
      if (!_sameDay(planner.selectedDate, _dayAnchor)) await planner.selectDate(_dayAnchor);
    } else if (mode == _PlannerViewMode.week) {
      await planner.setScope(ScheduleScope.week);
    } else if (planner.scope != ScheduleScope.week) {
      await planner.setScope(ScheduleScope.week);
    }
  }

  Future<void> _chooseStripDay(DateTime day, PlannerController planner) async {
    setState(() => _viewMode = _PlannerViewMode.day);
    if (planner.scope != ScheduleScope.day) await planner.setScope(ScheduleScope.day);
    await planner.selectDate(day);
    _dayAnchor = planner.selectedDate;
  }

  Widget _weekStrip(BuildContext context, PlannerController planner) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final start = planner.selectedDate.subtract(Duration(days: planner.selectedDate.weekday - 1));
    final rows = _visibleRows(planner, null);
    final counts = <DateTime, int>{};
    for (final row in rows) {
      final day = DateTime(row.at.year, row.at.month, row.at.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          for (var index = 0; index < 7; index++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final day = start.add(Duration(days: index));
                  final selected = _sameDay(day, planner.selectedDate);
                  final count = counts[_dateOnly(day)] ?? 0;
                  return Semantics(
                    button: true,
                    selected: selected,
                    label: '${names[day.weekday - 1]} ${day.day}',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _chooseStripDay(day, planner),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 78,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF0B6259) : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: selected ? null : Border.all(color: const Color(0xFFE7E3DC)),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              names[day.weekday - 1],
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 12,
                                color: selected ? Colors.white : const Color(0xFF294D65),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${day.day}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: selected ? Colors.white : const Color(0xFF102C3D),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? (selected ? Colors.white : _dayDotColor(context, day, rows))
                                    : (selected ? Colors.white70 : const Color(0xFFB7B4AE)),
                                shape: BoxShape.circle,
                              ),
                            ),
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
    );
  }

  Widget _viewControls(BuildContext context, PlannerController planner) {
    const modes = [
      _PlannerViewMode.day,
      _PlannerViewMode.week,
      _PlannerViewMode.month,
      _PlannerViewMode.agenda,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: [
                  for (final mode in modes)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: _viewMode == mode,
                        label: _modeLabel(mode),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => _chooseView(mode, planner),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _viewMode == mode ? const Color(0xFFCFE4DD) : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Text(
                              _modeLabel(mode),
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _viewMode == mode ? const Color(0xFF0B544B) : const Color(0xFF102C3D),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _showFilters,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(92, 48),
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(color: Theme.of(context).dividerColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            icon: const Icon(Icons.filter_alt_outlined, size: 18),
            label: Text(_filterCount == 0 ? 'Filters' : 'Filters $_filterCount'),
          ),
        ],
      ),
    );
  }

  String _modeLabel(_PlannerViewMode mode) => switch (mode) {
        _PlannerViewMode.day => 'Day',
        _PlannerViewMode.week => 'Week',
        _PlannerViewMode.month => 'Month',
        _PlannerViewMode.agenda => 'Agenda',
      };

  int get _filterCount => _kinds.length + (_completedFilter == null ? 0 : 1) + (_hideCompleted ? 1 : 0);

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

  List<Widget> _timelineView(BuildContext context, PlannerController planner, DashboardResponse? dashboard) {
    if ((planner.scheduleLoading || planner.loading) && planner.schedule == null) {
      return const [SliverToBoxAdapter(child: SkeletonLoader(rows: 5, rowHeight: 72))];
    }
    if (planner.scheduleError != null && planner.schedule == null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ErrorRetry(
              message: "Couldn't load your schedule.",
              onRetry: planner.loadSchedule,
            ),
          ),
        ),
      ];
    }
    final rows = _visibleRows(planner, dashboard);
    if (rows.isEmpty) return [SliverToBoxAdapter(child: _emptyCard(context, planner))];
    return [SliverToBoxAdapter(child: _scheduleCard(context, planner, rows))];
  }

  Widget _scheduleCard(BuildContext context, PlannerController planner, List<_Row> rows) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final showDay = planner.scope == ScheduleScope.week;
    final currentOffset = _currentTimeOffset(rows, now);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      _longDate(planner.selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'serif',
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _scheduleSummary(rows),
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF55728A),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.45)),
            CustomPaint(
              painter: _TimelinePainter(
                 color: const Color(0xFF0B6259),
                 currentOffset: currentOffset,
                 rowHeight: _timelineRowHeight,
                 textDirection: Directionality.of(context),
              ),
              child: Column(
                children: [
                  for (var index = 0; index < rows.length; index++)
                    _timelineRow(context, rows[index], showDay: showDay),
                ],
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _timelineRow(BuildContext context, _Row row, {required bool showDay}) {
    final theme = Theme.of(context);
    final sourceColor = _sourceColor(row.kind);
    final background = _pastel(context, sourceColor);
    return SizedBox(
      height: _timelineRowHeight,
      child: InkWell(
        onTap: () => _openRow(context, row),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Row(
            children: [
              SizedBox(
                width: 62,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.timed ? row.timeLabel.split('–').first : 'Anytime',
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF55728A),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (showDay)
                      Text(
                        '${_weekday(row.at.weekday)} ${row.at.day}',
                        style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFF7A8A98)),
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 20,
                child: Center(
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(color: sourceColor, shape: BoxShape.circle),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 70,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.fromLTRB(8, 9, 8, 8),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: sourceColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(_sourceIcon(row.kind), color: sourceColor, size: 23),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontFamily: 'serif',
                                fontWeight: FontWeight.w800,
                                decoration: row.done ? TextDecoration.lineThrough : null,
                                color: row.done ? theme.disabledColor : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              row.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF55728A),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (row.reminder != TaskReminderMode.none)
                        Icon(
                          row.done ? Icons.check_circle : Icons.notifications_none,
                          color: row.done ? const Color(0xFF079447) : theme.colorScheme.error,
                          size: 20,
                        ),
                      const SizedBox(width: 7),
                      _completionMark(row.done),
                      const SizedBox(width: 4),
                      const Icon(Icons.more_vert, size: 19, color: Color(0xFF55728A)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _currentTimeOffset(List<_Row> rows, DateTime now) {
    if (rows.isEmpty || !rows.any((row) => _sameDay(row.at, now))) return null;
    var index = -1;
    for (var i = 0; i < rows.length; i++) {
      if (!rows[i].at.isAfter(now)) {
        index = i;
      } else {
        break;
      }
    }
    if (index < 0) return 0;
    if (index == rows.length - 1) return (rows.length - 0.5) * _timelineRowHeight;
    final previous = rows[index].at;
    final next = rows[index + 1].at;
    final total = next.difference(previous).inMilliseconds;
    final fraction = total <= 0 ? 0.5 : now.difference(previous).inMilliseconds / total;
    return (index + fraction.clamp(0.08, 0.92).toDouble()) * _timelineRowHeight;
  }

  Widget _completionMark(bool done) {
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: done ? const Color(0xFF079447) : Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(color: done ? const Color(0xFF079447) : const Color(0xFF55728A), width: 1.7),
      ),
      child: done ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
    );
  }

  List<Widget> _monthView(BuildContext context, PlannerController planner, DashboardResponse? dashboard) {
    final rows = _visibleRows(planner, dashboard);
    final month = DateTime(planner.selectedDate.year, planner.selectedDate.month);
    final monthRows = rows.where((row) => row.at.year == month.year && row.at.month == month.month).toList();
    return [SliverToBoxAdapter(child: _monthCard(context, planner, month, monthRows))];
  }

  Widget _monthCard(BuildContext context, PlannerController planner, DateTime month, List<_Row> rows) {
    final theme = Theme.of(context);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final leading = DateTime(month.year, month.month).weekday - 1;
    final cellCount = ((leading + days + 6) ~/ 7) * 7;
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthName(month.year, month.month),
                  style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w800),
                ),
              ),
              Text('${rows.length} loaded items', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF55728A))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final label in labels)
                Expanded(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(color: const Color(0xFF55728A), fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          for (var cell = 0; cell < cellCount; cell += 7)
            Row(
              children: [
                for (var weekday = 0; weekday < 7; weekday++)
                  Expanded(child: _monthCell(context, planner, month, leading + cell + weekday - leading, days, rows)),
              ],
            ),
          const Divider(height: 18),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No loaded schedule items in this month.', style: theme.textTheme.bodyMedium),
            )
          else
            for (final row in rows.take(8)) _agendaRow(context, row, showDate: true),
          if (rows.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Showing the first 8 loaded items.', style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _monthCell(BuildContext context, PlannerController planner, DateTime month, int dayNumber, int days, List<_Row> rows) {
    if (dayNumber < 1 || dayNumber > days) return const SizedBox(height: 58);
    final date = DateTime(month.year, month.month, dayNumber);
    final dayRows = rows.where((row) => _sameDay(row.at, date)).toList();
    final selected = _sameDay(date, planner.selectedDate);
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _chooseStripDay(date, planner),
      child: Container(
        height: 58,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0B6259) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w700, color: selected ? Colors.white : null),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (dayRows.isEmpty)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white54 : theme.dividerColor,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  for (final row in dayRows.take(3))
                    Container(
                      width: 5,
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : _sourceColor(row.kind),
                        shape: BoxShape.circle,
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _agendaView(BuildContext context, PlannerController planner, DashboardResponse? dashboard) {
    final rows = _visibleRows(planner, dashboard);
    if (rows.isEmpty) return [SliverToBoxAdapter(child: _emptyCard(context, planner))];
    return [SliverToBoxAdapter(child: _agendaCard(context, rows))];
  }

  Widget _agendaCard(BuildContext context, List<_Row> rows) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.035), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Agenda', style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text('${rows.length} loaded schedule items', style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF55728A))),
          const SizedBox(height: 10),
          for (var index = 0; index < rows.length; index++) ...[
            if (index == 0 || !_sameDay(rows[index - 1].at, rows[index].at))
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 5),
                child: Text(
                  _longDate(rows[index].at),
                  style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w800),
                ),
              ),
            _agendaRow(context, rows[index]),
          ],
        ],
      ),
    );
  }

  Widget _agendaRow(BuildContext context, _Row row, {bool showDate = false}) {
    final theme = Theme.of(context);
    final sourceColor = _sourceColor(row.kind);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openRow(context, row),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: _pastel(context, sourceColor), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(_sourceIcon(row.kind), color: sourceColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w800,
                      decoration: row.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    showDate ? '${row.timeLabel} · ${row.subtitle}' : row.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF55728A)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF55728A)),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(BuildContext context, PlannerController planner) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          const Icon(Icons.event_available_outlined, size: 44, color: Color(0xFF0B6259)),
          const SizedBox(height: 12),
          Text(
            _hasActiveFilters ? 'No schedule items match these filters.' : 'No tasks or events scheduled.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            planner.isTodaySelected ? 'Your schedule is clear for this day.' : 'Try another day or adjust your filters.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: const Color(0xFF55728A)),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 12),
            TextButton(onPressed: _clearFilters, child: const Text('Clear filters')),
          ] else ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final action = await showQuickAdd(context);
                if (action != null && context.mounted) await openQuickAddCreation(context, action);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasActiveFilters => _filterCount > 0;

  void _clearFilters() {
    setState(() {
      _kinds.clear();
      _completedFilter = null;
      _hideCompleted = false;
    });
  }

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

  Color _dayDotColor(BuildContext context, DateTime day, List<_Row> rows) {
    final match = rows.where((row) => _sameDay(row.at, day));
    return match.isEmpty ? const Color(0xFFB7B4AE) : _sourceColor(match.first.kind);
  }

  String _scheduleSummary(List<_Row> rows) {
    final tasks = rows.where((row) => row.kind == _RowKind.task).length;
    final events = rows.where((row) => row.kind == _RowKind.event).length;
    final other = rows.length - tasks - events;
    return '$tasks ${tasks == 1 ? 'task' : 'tasks'} · $events ${events == 1 ? 'event' : 'events'}${other > 0 ? ' · $other more' : ''}';
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
        kind: _RowKind.event,
        timed: true,
        done: event.status == EventStatus.completed,
        timeLabel: '${_time(start)}–${_time(end)}',
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
        kind: _RowKind.task,
        timed: timed,
        done: task.status == TaskStatus.completed,
        timeLabel: timed ? _taskTime(task, start, end) : 'Anytime',
        task: task,
        reminder: task.reminderMode,
      ));
    }
    if (planner.isTodaySelected) {
      for (final task in planner.today?.overdueTasks ?? const <PlannerTask>[]) {
        if (seenTasks.contains(task.id) || !_matches(task.title, task.description, task.taskListName, query)) continue;
        final at = (task.dueAt ?? task.dueDate)?.toLocal() ?? planner.selectedDate;
        rows.add(_Row(at: at, title: task.title, subtitle: _taskSubtitle(task),         kind: _RowKind.task, timed: taskHasExplicitTime(task), done: false, timeLabel: 'Overdue', task: task, reminder: task.reminderMode));
      }
    }
    if (includeCrossModule && planner.isTodaySelected && dashboard != null) {
      final medicines = dashboard.medicines;
      if (medicines != null && !medicines.unavailable) {
        for (final dose in medicines.dosesToday) {
          final at = DateTime.tryParse(dose.scheduledAt)?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(dose.medicineName, null, null, query)) continue;
          final status = dose.status.toUpperCase();
          rows.add(_Row(at: at, title: dose.medicineName, subtitle: 'Medicine · ${_time(at)}', kind: _RowKind.medicine, timed: true, done: status == 'TAKEN', cancelled: status == 'SKIPPED', timeLabel: _time(at), id: dose.medicineId));
        }
      }
      final habits = dashboard.habits;
      if (habits != null && !habits.unavailable) {
        for (final habit in habits.todayHabits) {
          if (!_matches(habit.name, null, null, query)) continue;
          rows.add(_Row(at: planner.selectedDate, title: habit.name, subtitle: 'Habit · no time set', kind: _RowKind.habit, timed: false, done: habit.completedToday, timeLabel: 'Anytime', id: habit.id));
        }
      }
      final diet = dashboard.diet;
      if (diet != null && !diet.unavailable) {
        for (final meal in diet.meals) {
          final at = DateTime.tryParse(meal.consumedAt ?? '')?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(_mealTitle(meal.type), null, null, query)) continue;
          rows.add(_Row(at: at, title: _mealTitle(meal.type), subtitle: 'Meal · ${_time(at)}', kind: _RowKind.meal, timed: true, done: true, timeLabel: _time(at), id: meal.id));
        }
      }
      final health = dashboard.health;
      if (health != null && !health.unavailable) {
        for (final appointment in health.upcomingAppointments) {
          final at = DateTime.tryParse(appointment.scheduledAt)?.toLocal();
          if (at == null || !_sameDay(at, planner.selectedDate) || !_matches(appointment.title, null, null, query)) continue;
          final status = (appointment.status ?? '').toUpperCase();
          rows.add(_Row(at: at, title: appointment.title, subtitle: 'Appointment · ${_time(at)}', kind: _RowKind.appointment, timed: true, done: status == 'COMPLETED', cancelled: status == 'CANCELLED', timeLabel: _time(at), id: appointment.id));
        }
      }
    }
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
    if (end != null && end.isAfter(start)) return '${_time(start)}–${_time(end)}';
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

  String _longDate(DateTime date) => '${_weekday(date.weekday)}, ${date.day} ${_monthName(date.year, date.month).split(' ').last}';

  String _monthName(int year, int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

  String _mealTitle(String? type) {
    if (type == null || type.isEmpty) return 'Meal';
    return type[0].toUpperCase() + type.substring(1).toLowerCase();
  }

  Color _pastel(BuildContext context, Color color) => Color.alphaBlend(
        color.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.11),
        Theme.of(context).colorScheme.surface,
      );

  Color _sourceColor(_RowKind kind) => switch (kind) {
        _RowKind.task => const Color(0xFF1677FF),
        _RowKind.event => const Color(0xFF9A35E8),
        _RowKind.medicine => const Color(0xFFF0445B),
        _RowKind.habit => const Color(0xFF10A55B),
        _RowKind.meal => const Color(0xFFFF8A20),
        _RowKind.appointment => const Color(0xFF0B8C9E),
      };

  IconData _sourceIcon(_RowKind kind) => switch (kind) {
        _RowKind.task => Icons.description_outlined,
        _RowKind.event => Icons.groups_2_outlined,
        _RowKind.medicine => Icons.medication_outlined,
        _RowKind.habit => Icons.directions_walk_outlined,
        _RowKind.meal => Icons.restaurant_outlined,
        _RowKind.appointment => Icons.medical_services_outlined,
      };
}

enum _PlannerViewMode { day, week, month, agenda }

const double _timelineRowHeight = 82;

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter({
    required this.color,
    required this.currentOffset,
    required this.rowHeight,
    required this.textDirection,
  });

  final Color color;
  final double? currentOffset;
  final double rowHeight;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final timelineX = 82.0;
    final line = Paint()
      ..color = color.withValues(alpha: 0.48)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(timelineX, 0), Offset(timelineX, size.height), line);
    if (currentOffset == null) return;
    final y = currentOffset!.clamp(12.0, size.height - 12.0).toDouble();
    final dashed = Paint()
      ..color = color
      ..strokeWidth = 1.4;
    const dash = 5.0;
    const gap = 4.0;
    for (var x = 67.0; x < size.width - 45; x += dash + gap) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(0, size.width - 45).toDouble(), y), dashed);
    }
    canvas.drawCircle(Offset(timelineX, y), 4, Paint()..color = color);
    final timeWidth = 58.0;
    final timeRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, y - 15, timeWidth, 30), const Radius.circular(9));
    canvas.drawRRect(timeRect, Paint()..color = color);
    final nowWidth = 48.0;
    final nowRect = RRect.fromRectAndRadius(Rect.fromLTWH(size.width - nowWidth, y - 15, nowWidth, 30), const Radius.circular(9));
    canvas.drawRRect(nowRect, Paint()..color = color);
    for (final item in [
      (timeRect, _displayTime(DateTime.now())),
      (nowRect, 'Now'),
    ]) {
      final painter = TextPainter(
        text: TextSpan(
          text: item.$2,
          style: const TextStyle(color: Colors.white, fontFamily: 'serif', fontSize: 11, fontWeight: FontWeight.w700),
        ),
        textDirection: textDirection,
      )..layout();
      painter.paint(canvas, Offset(item.$1.left + (item.$1.width - painter.width) / 2, item.$1.top + (item.$1.height - painter.height) / 2));
    }
  }

  String _displayTime(DateTime value) {
    final hour = value.hour == 0 ? 12 : value.hour > 12 ? value.hour - 12 : value.hour;
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${value.minute.toString().padLeft(2, '0')} $suffix';
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) => oldDelegate.currentOffset != currentOffset || oldDelegate.color != color;
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
    const kinds = [
      (_RowKind.task, 'Tasks', Icons.task_alt),
      (_RowKind.event, 'Events', Icons.event),
      (_RowKind.medicine, 'Medicine', Icons.medication_outlined),
      (_RowKind.habit, 'Habits', Icons.repeat),
      (_RowKind.meal, 'Meals', Icons.restaurant_outlined),
      (_RowKind.appointment, 'Appointments', Icons.medical_services_outlined),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter your schedule', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontFamily: 'serif', fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('Choose what appears in every Planner view.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              Text('Item type', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
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
                      avatar: Icon(kind.$3, size: 17),
                      label: Text(kind.$2),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Completion', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              SegmentedButton<bool?>(
                segments: const [
                  ButtonSegment(value: null, label: Text('All')),
                  ButtonSegment(value: false, label: Text('Open')),
                  ButtonSegment(value: true, label: Text('Completed')),
                ],
                selected: {_completed},
                onSelectionChanged: (selection) => setState(() => _completed = selection.first),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hide completed items'),
                value: _hideCompleted,
                onChanged: (value) => setState(() => _hideCompleted = value),
              ),
              const SizedBox(height: 12),
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
    required this.subtitle,
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
  final String subtitle;
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
