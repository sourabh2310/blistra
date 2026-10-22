/// Statistics screen showing streak and completion data for each habit.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/glass.dart';
import '../habit_insights.dart';
import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';
import 'habit_detail_screen.dart';
import 'habit_form_screen.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);

    if (controller.activeHabits.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
        children: [
          PagePad(
            EmptyCard(
              message: 'No active habits to show statistics for.',
              action: 'Create habit',
              onAction: () => showHabitFormSheet(context),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(kPageGutter, 6, kPageGutter, 28),
      itemCount: controller.activeHabits.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final Habit habit = controller.activeHabits[index];
        return _StatisticsCard(
          key: ValueKey(habit.id),
          habit: habit,
        );
      },
    );
  }
}

class _StatisticsCard extends StatefulWidget {
  const _StatisticsCard({super.key, required this.habit});

  final Habit habit;

  @override
  State<_StatisticsCard> createState() => _StatisticsCardState();
}

class _StatisticsCardState extends State<_StatisticsCard> {
  HabitStatisticsResponse? _stats;
  bool _loading = true;
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
    if (!_loading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final HabitStatisticsResponse stats =
          await controller.fetchStatistics(widget.habit.id);
      if (mounted) {
        setState(() {
          _stats = stats;
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

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final HabitStatisticsResponse? stats = _stats;

    return GlassCard(
      padding: const EdgeInsets.all(15),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HabitDetailScreen(habitId: widget.habit.id),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconWell(habitTypeIcon(widget.habit.type),
                  color: colors.accentText, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.habit.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BlistraText.serif(17, colors.text),
                ),
              ),
              if (stats != null && stats.currentStreak > 0)
                Pill('🔥 ${pluralDays(stats.currentStreak)}'),
            ],
          ),
          const SizedBox(height: 14),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Statistics couldn't load",
                    style: TextStyle(fontSize: 12.5, color: colors.danger),
                  ),
                ),
                Pill('Retry', onTap: _load),
              ],
            )
          else if (stats != null) ...[
            Row(
              children: [
                Expanded(
                  child: Figure(
                    label: 'Current',
                    value: pluralDays(stats.currentStreak),
                  ),
                ),
                Expanded(
                  child: Figure(
                    label: 'Best',
                    value: pluralDays(stats.bestStreak),
                  ),
                ),
                Expanded(
                  child: Figure(
                    label: 'Total',
                    value: '${stats.totalCompletions}',
                  ),
                ),
              ],
            ),
            if (stats.completionRate != null) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'COMPLETION RATE',
                    style: BlistraText.caption(colors.muted),
                  ),
                  const Spacer(),
                  Text(
                    stats.completionRateLabel!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colors.text,
                      fontFeatures: BlistraText.tabular,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ProgressLine(value: stats.completionRate!),
            ],
            const SizedBox(height: 10),
            Text(
              [
                ?stats.occurrencesLabel,
                stats.lastCompletedOn != null
                    ? 'Last completed ${DateFormat('MMM d, yyyy').format(stats.lastCompletedOn!.toLocal())}'
                    : 'Never completed',
              ].join(' · '),
              style: TextStyle(fontSize: 11, color: colors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
