/// Today screen: this week's completion rate, habits due today with a
/// one-tap check, streaks and a 7-day history, then the ones already done.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../habit_insights.dart';
import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';
import 'habit_detail_screen.dart';
import 'habit_form_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.insights, this.onManage});

  final HabitInsights insights;

  /// Opens the full habit list.
  final VoidCallback? onManage;

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final Set<String> _busy = {};

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);
    final HabitInsights insights = widget.insights;

    if (controller.todayHabits.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
        children: [
          PagePad(
            EmptyCard(
              message:
                  'No active habits due today. Create a habit and add a schedule!',
              action: 'Create habit',
              onAction: () => showHabitFormSheet(context),
            ),
          ),
          if (controller.hasHabits) ...[
            const SizedBox(height: 24),
            _manageHeader(),
          ],
        ],
      );
    }

    final List<HabitTodayResponse> due = controller.dueToday;
    final List<HabitTodayResponse> done = controller.doneToday;

    return ListenableBuilder(
      listenable: insights,
      builder: (BuildContext context, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
        children: [
          PagePad(_WeekCard(week: insights.week())),
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Due today',
            actionLabel: due.isEmpty ? null : '${due.length} left',
          ),
          PagePad(
            due.isEmpty
                ? const EmptyCard(message: 'Everything due today is done.')
                : GlassList(
                    children: [
                      for (final HabitTodayResponse habit in due)
                        _row(controller, insights, habit, showHistory: true),
                    ],
                  ),
          ),
          if (done.isNotEmpty) ...[
            const SizedBox(height: 24),
            SectionHeader(title: 'Done', actionLabel: '${done.length}'),
            PagePad(
              GlassList(
                children: [
                  for (final HabitTodayResponse habit in done)
                    _row(controller, insights, habit, showHistory: false),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          _manageHeader(),
        ],
      ),
    );
  }

  Widget _manageHeader() => SectionHeader(
        title: 'All habits',
        actionLabel: 'Manage ›',
        onAction: widget.onManage,
      );

  Widget _row(
    HabitsController controller,
    HabitInsights insights,
    HabitTodayResponse habit, {
    required bool showHistory,
  }) {
    final HabitStatisticsResponse? stats = insights.statsFor(habit.id);
    final Set<DateTime>? days = insights.daysFor(habit.id);
    return GlassRow(
      leading: CheckCircle(
        checked: habit.completedToday,
        busy: _busy.contains(habit.id),
        semanticLabel: habit.completedToday
            ? 'Mark ${habit.name} not done'
            : 'Mark ${habit.name} done',
        onTap: () => _toggle(controller, habit, !habit.completedToday),
      ),
      title: habit.name,
      subtitle: stats != null ? streakLabel(stats) : _fallbackSubtitle(habit),
      trailing: showHistory && days != null ? _WeekDots(days: days) : null,
      onTap: () => _openDetail(context, habit),
    );
  }

  /// Shown until (or if never) statistics load: real habit details only.
  String? _fallbackSubtitle(HabitTodayResponse habit) {
    final List<String> parts = [
      if (habit.schedule != null) scheduleLabel(habit.schedule!),
      ?habitTargetLabel(
        targetValue: habit.targetValue,
        targetUnit: habit.targetUnit,
        targetMinutes: habit.targetMinutes,
      ),
    ];
    if (parts.isEmpty) return habit.description;
    return parts.join(' · ');
  }

  Future<void> _toggle(
    HabitsController controller,
    HabitTodayResponse habit,
    bool nowCompleted,
  ) async {
    setState(() => _busy.add(habit.id));
    final bool ok =
        await toggleTodayCompletion(context, controller, habit, nowCompleted);
    if (ok) widget.insights.refresh(habit.id);
    if (mounted) setState(() => _busy.remove(habit.id));
  }

  void _openDetail(BuildContext context, HabitTodayResponse habit) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: habit.id),
          ),
        )
        .then((_) => widget.insights.refresh(habit.id));
  }
}

/// "This week" completion rate with one bar per day, Monday first.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});

  final HabitWeek week;

  static const List<String> _letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final double? rate = week.rate;
    final int todayIndex = DateTime.now().weekday - 1;
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('THIS WEEK', style: BlistraText.caption(colors.muted)),
                const SizedBox(height: 3),
                Text(
                  rate == null ? '—' : '${(rate * 100).round()}%',
                  style: BlistraText.serif(24, colors.text),
                ),
                const SizedBox(height: 2),
                Text(
                  week.due == 0
                      ? 'Nothing due yet'
                      : '${week.done} of ${week.due} check-ins',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          for (int i = 0; i < 7; i++) ...[
            if (i > 0) const SizedBox(width: 5),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 44,
                  width: 14,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 14,
                      height: 44 * (week.days[i] ?? 0).clamp(0.18, 1.0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: (week.days[i] ?? 0) == 0
                            ? colors.inkAt(0.1)
                            : i == todayIndex
                                ? colors.accentText
                                : colors.accentText.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _letters[i],
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: i == todayIndex ? colors.accentText : colors.muted,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Seven dots for the last seven days, oldest first; filled when completed.
class _WeekDots extends StatelessWidget {
  const _WeekDots({required this.days});

  final Set<DateTime> days;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final DateTime today = habitToday();
    final int count = [
      for (int i = 0; i < 7; i++)
        if (days.contains(DateTime(today.year, today.month, today.day - i))) i,
    ].length;
    return Semantics(
      label: 'Completed $count of the last 7 days',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 6; i >= 0; i--) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: days.contains(
                        DateTime(today.year, today.month, today.day - i))
                    ? colors.accentText
                    : colors.inkAt(0.15),
              ),
            ),
            if (i > 0) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }
}
