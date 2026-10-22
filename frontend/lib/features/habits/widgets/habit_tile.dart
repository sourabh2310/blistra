/// Reusable habit row for today lists: a one-tap check, name and schedule.
/// Place inside a [GlassList].
library;

import 'package:flutter/material.dart';

import '../../../core/widgets/blistra_ui.dart';
import '../habit_insights.dart';
import '../models.dart';

class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.onToggle,
    required this.onTap,
    this.busy = false,
  });

  final HabitTodayResponse habit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final List<String> parts = [
      if (habit.schedule != null) scheduleLabel(habit.schedule!),
      ?habitTargetLabel(
        targetValue: habit.targetValue,
        targetUnit: habit.targetUnit,
        targetMinutes: habit.targetMinutes,
      ),
    ];
    return GlassRow(
      leading: CheckCircle(
        checked: habit.completedToday,
        busy: busy,
        semanticLabel: habit.completedToday
            ? 'Mark ${habit.name} not done'
            : 'Mark ${habit.name} done',
        onTap: () => onToggle(!habit.completedToday),
      ),
      title: habit.name,
      subtitle: parts.isEmpty ? habit.description : parts.join(' · '),
      onTap: onTap,
    );
  }
}
