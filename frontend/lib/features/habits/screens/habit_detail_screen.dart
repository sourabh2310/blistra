/// Habit detail screen: streak stats, a calendar heatmap of completions,
/// schedule and history, with the day's check-in pinned at the bottom.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../habit_insights.dart';
import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';
import 'habit_form_screen.dart';

class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});

  final String habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  Habit? _habit;
  Schedule? _schedule;
  List<Completion> _completions = const [];
  HabitStatisticsResponse? _stats;
  bool _statsFailed = false;
  bool _completionsFailed = false;
  bool _loading = true;
  bool _toggling = false;
  bool _showAllHistory = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Read without subscribing: _load first runs from initState.
    final HabitsController controller =
        context.getInheritedWidgetOfExactType<HabitsScope>()!.notifier!;
    try {
      await Future.wait([
        _loadHabit(controller),
        _loadSchedule(controller),
        _loadCompletions(controller),
        _loadStats(controller),
      ]);
      if (mounted) {
        setState(() {
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _retry() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _load();
  }

  Future<void> _loadHabit(HabitsController controller) async {
    _habit = await controller.api.getHabit(widget.habitId);
  }

  Future<void> _loadSchedule(HabitsController controller) async {
    try {
      _schedule = await controller.api.getSchedule(widget.habitId);
    } catch (_) {
      _schedule = null;
    }
  }

  // Completions and statistics degrade to an "unavailable" section instead
  // of failing the whole page.
  Future<void> _loadCompletions(HabitsController controller) async {
    try {
      final PageResult<Completion> result =
          await controller.api.fetchCompletions(widget.habitId, size: 100);
      _completions = result.items;
      _completionsFailed = false;
    } catch (_) {
      _completionsFailed = true;
    }
  }

  Future<void> _loadStats(HabitsController controller) async {
    try {
      _stats = await controller.fetchStatistics(widget.habitId);
      _statsFailed = false;
    } catch (_) {
      _statsFailed = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: ListView(
            children: [
              const BlistraPageHeader(eyebrow: 'Habit', title: 'Habit details'),
              PagePad(
                EmptyCard(
                  message: 'Error: $_error',
                  action: 'Retry',
                  onAction: _retry,
                ),
                top: 12,
              ),
            ],
          ),
        ),
      );
    }

    final Habit habit = _habit!;
    final HabitsController controller = HabitsScope.of(context);
    HabitTodayResponse? today;
    for (final HabitTodayResponse h in controller.todayHabits) {
      if (h.id == habit.id) today = h;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 110),
            children: [
              BlistraPageHeader(
                eyebrow: 'Habit',
                title: habit.name,
                subtitle: _meta(habit),
                actions: [
                  GlassIconButton(
                    tooltip: 'Edit',
                    icon: Icons.edit_outlined,
                    onTap: () => _showEditSheet(context),
                  ),
                  if (!habit.isArchived)
                    GlassIconButton(
                      tooltip: 'Archive',
                      icon: Icons.archive_outlined,
                      onTap: () => _archive(context),
                    ),
                ],
              ),
              if (habit.description != null && habit.description!.isNotEmpty)
                PagePad(_AboutCard(text: habit.description!), top: 8),
              const SizedBox(height: 14),
              if (_stats != null)
                _StatsStrip(stats: _stats!)
              else if (_statsFailed)
                PagePad(UnavailableCard(name: 'Statistics', onRetry: _load)),
              const SizedBox(height: 24),
              const SectionHeader(title: 'Activity', actionLabel: 'Last 14 weeks'),
              PagePad(
                _completionsFailed
                    ? UnavailableCard(name: 'Activity', onRetry: _load)
                    : _Heatmap(
                        days: {
                          for (final Completion c in _completions)
                            habitDay(c.completedOn),
                        },
                        schedule: _schedule,
                        createdOn: habitDay(habit.createdAt),
                      ),
              ),
              const SizedBox(height: 24),
              SectionHeader(
                title: 'Schedule',
                actionLabel: 'Edit ›',
                onAction: () => _showEditSheet(context),
              ),
              PagePad(_ScheduleList(habit: habit, schedule: _schedule)),
              if (!_completionsFailed) ...[
                const SizedBox(height: 24),
                SectionHeader(
                  title: 'History',
                  actionLabel: _completions.isEmpty
                      ? null
                      : '${_completions.length}',
                ),
                PagePad(_history(habit)),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: today == null
          ? StickyActionBar(
              label: 'Edit habit',
              onPressed: () => _showEditSheet(context),
            )
          : StickyActionBar(
              label: today.completedToday
                  ? 'Undo today’s check-in'
                  : 'Mark done today',
              busy: _toggling,
              onPressed: () => _toggleToday(controller, today!),
            ),
    );
  }

  /// "Count · Daily · since 3 Jan", plus the status when not active.
  String _meta(Habit habit) {
    final List<String> parts = [
      habitTypeLabel(habit.type),
      if (_schedule != null) scheduleLabel(_schedule!),
      'since ${DateFormat('d MMM yyyy').format(habit.createdAt.toLocal())}',
      if (!habit.isActive) habitStatusLabel(habit.status),
    ];
    return parts.join(' · ');
  }

  Widget _history(Habit habit) {
    if (_completions.isEmpty) {
      return const EmptyCard(message: 'No completions yet');
    }
    const int preview = 7;
    final List<Completion> shown = _showAllHistory
        ? _completions
        : _completions.take(preview).toList();
    return GlassList(
      children: [
        for (final Completion c in shown)
          GlassRow(
            leading: const CheckCircle(checked: true),
            title: _dayLabel(c.completedOn),
            subtitle: _completionSubtitle(habit.type, c),
          ),
        if (_completions.length > preview)
          GlassRow(
            title: _showAllHistory
                ? 'Show fewer'
                : 'Show all ${_completions.length}',
            titleColor: BlistraColors.resolve(context).accentText,
            onTap: () => setState(() => _showAllHistory = !_showAllHistory),
          ),
      ],
    );
  }

  String _dayLabel(DateTime day) {
    final DateTime today = habitToday();
    final DateTime that = habitDay(day);
    if (that == today) {
      return 'Today';
    }
    if (that == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, MMM d, yyyy').format(day.toLocal());
  }

  String? _completionSubtitle(HabitType habitType, Completion c) {
    switch (habitType) {
      case HabitType.count:
        return c.value != null ? 'Quantity: ${c.value}' : null;
      case HabitType.duration:
        return c.durationMinutes != null ? '${c.durationMinutes} min' : null;
      case HabitType.boolean:
        return null;
    }
  }

  Future<void> _toggleToday(
    HabitsController controller,
    HabitTodayResponse habit,
  ) async {
    setState(() => _toggling = true);
    final bool ok = await toggleTodayCompletion(
        context, controller, habit, !habit.completedToday);
    if (ok) await _load();
    if (mounted) setState(() => _toggling = false);
  }

  void _showEditSheet(BuildContext context) {
    showHabitFormSheet(context, existingHabit: _habit!).then((_) => _load());
  }

  Future<void> _archive(BuildContext context) async {
    final HabitsController controller = HabitsScope.of(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Archive habit?'),
        content: Text(
            '"${_habit!.name}" will be hidden from active lists. Completion history will be kept.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await controller.archiveHabit(_habit!.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Habit archived')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, height: 1.45, color: colors.text),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.stats});

  final HabitStatisticsResponse stats;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final double? rate = stats.completionRate;
    final int? due = stats.dueOccurrences;
    final int? doneDue = stats.completedDueOccurrences;
    final DateTime? last = stats.lastCompletedOn;
    return StatStrip(
      stats: [
        StatData(
          label: 'Current streak',
          value: '${stats.currentStreak}',
          unit: stats.currentStreak == 1 ? 'day' : 'days',
          sub: last == null
              ? 'Not started'
              : 'Last ${DateFormat('MMM d').format(last.toLocal())}',
          icon: Icons.local_fire_department_outlined,
        ),
        StatData(
          label: 'Best streak',
          value: '${stats.bestStreak}',
          unit: stats.bestStreak == 1 ? 'day' : 'days',
          sub: 'All time',
          icon: Icons.emoji_events_outlined,
        ),
        StatData(
          label: 'Completion rate',
          value: rate == null ? '—' : '${(rate * 100).round()}',
          unit: rate == null ? '' : '%',
          sub: due != null && doneDue != null
              ? '$doneDue of $due due'
              : 'Nothing due yet',
          progress: rate,
          color: colors.accentText,
          icon: Icons.percent_rounded,
        ),
        StatData(
          label: 'Check-ins',
          value: '${stats.totalCompletions}',
          sub: 'All time',
          icon: Icons.check_circle_outline_rounded,
        ),
      ],
    );
  }
}

/// Calendar heatmap of the last 14 weeks: one column per week (Monday on
/// top), filled on days with a completion.
class _Heatmap extends StatelessWidget {
  const _Heatmap({
    required this.days,
    required this.schedule,
    required this.createdOn,
  });

  final Set<DateTime> days;
  final Schedule? schedule;
  final DateTime createdOn;

  static const int _weeks = 14;
  static const double _gap = 3;
  static const double _labelWidth = 16;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final DateTime today = habitToday();
    final DateTime thisMonday =
        today.subtract(Duration(days: today.weekday - 1));
    final DateTime start = DateTime(
        thisMonday.year, thisMonday.month, thisMonday.day - 7 * (_weeks - 1));
    final int count = days
        .where((DateTime d) => !d.isBefore(start) && !d.isAfter(today))
        .length;

    DateTime dayAt(int week, int weekday) =>
        DateTime(start.year, start.month, start.day + week * 7 + weekday);

    Color cellColor(DateTime day) {
      if (day.isAfter(today)) return Colors.transparent;
      if (days.contains(day)) return colors.accentText;
      final bool due = schedule != null &&
          !day.isBefore(createdOn) &&
          isHabitDueOn(schedule!, day);
      return colors.inkAt(due ? 0.13 : 0.05);
    }

    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double cell = ((constraints.maxWidth - _labelWidth) -
                  _gap * (_weeks - 1)) /
              _weeks;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count == 1
                    ? '1 check-in in 14 weeks'
                    : '$count check-ins in 14 weeks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              const SizedBox(height: 10),
              // Month labels above the first week column of each month.
              SizedBox(
                height: 14,
                child: Stack(
                  children: [
                    for (int w = 0; w < _weeks; w++)
                      if (w == 0 ||
                          dayAt(w, 0).month != dayAt(w - 1, 0).month)
                        Positioned(
                          left: _labelWidth + w * (cell + _gap),
                          child: Text(
                            DateFormat('MMM').format(dayAt(w, 0)),
                            style: TextStyle(fontSize: 9, color: colors.muted),
                          ),
                        ),
                  ],
                ),
              ),
              for (int d = 0; d < 7; d++) ...[
                if (d > 0) const SizedBox(height: _gap),
                Row(
                  children: [
                    SizedBox(
                      width: _labelWidth,
                      child: Text(
                        d.isEven ? const ['M', 'W', 'F', 'S'][d ~/ 2] : '',
                        style: TextStyle(fontSize: 9, color: colors.muted),
                      ),
                    ),
                    for (int w = 0; w < _weeks; w++) ...[
                      if (w > 0) const SizedBox(width: _gap),
                      Container(
                        width: cell,
                        height: cell,
                        decoration: BoxDecoration(
                          color: cellColor(dayAt(w, d)),
                          borderRadius: BorderRadius.circular(cell / 3.5),
                          border: dayAt(w, d) == today
                              ? Border.all(color: colors.accentText, width: 1.4)
                              : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  _LegendDot(color: colors.accentText, label: 'Done'),
                  if (schedule != null) ...[
                    const SizedBox(width: 12),
                    _LegendDot(color: colors.inkAt(0.13), label: 'Missed'),
                    const SizedBox(width: 12),
                    _LegendDot(color: colors.inkAt(0.05), label: 'Not due'),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 10, color: colors.muted)),
      ],
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({required this.habit, required this.schedule});

  final Habit habit;
  final Schedule? schedule;

  @override
  Widget build(BuildContext context) {
    final String? target = habitTargetLabel(
      targetValue: habit.targetValue,
      targetUnit: habit.targetUnit,
      targetMinutes: habit.targetMinutes,
    );
    final Schedule? s = schedule;
    return GlassList(
      children: [
        GlassRow(
          leading: const IconWell(Icons.repeat_rounded),
          title: s == null
              ? 'No schedule'
              : s.frequency == HabitFrequency.daily
                  ? 'Daily'
                  : 'Weekly on ${scheduleLabel(s)}',
          subtitle: s == null
              ? 'Not due on any day yet'
              : s.frequency == HabitFrequency.daily
                  ? 'Every day'
                  : s.daysOfWeek.length == 1
                      ? '1 day a week'
                      : '${s.daysOfWeek.length} days a week',
        ),
        if (target != null)
          GlassRow(
            leading: const IconWell(Icons.flag_outlined),
            title: 'Target: $target',
          ),
        GlassRow(
          leading: IconWell(habitTypeIcon(habit.type)),
          title: habitTypeLabel(habit.type),
          subtitle: habitStatusLabel(habit.status),
        ),
      ],
    );
  }
}
