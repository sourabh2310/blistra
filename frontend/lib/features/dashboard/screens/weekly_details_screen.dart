import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dashboard_response.dart';

/// Read-only weekly overview for the mixed Home summary.
///
/// Home aggregates tasks + habits, so routing this screen to Habits stats
/// would be wrong (it would hide task progress). This destination shows the
/// real backend-calculated week window with explicit definitions:
///
/// - Habit completion = completed scheduled occurrences / scheduled
///   occurrences (active habits only).
/// - Task completion = completed due-or-scheduled tasks / due-or-scheduled
///   tasks.
/// - Active days = distinct local dates with task completions or valid habit
///   completions.
class WeeklyDetailsScreen extends StatelessWidget {
  const WeeklyDetailsScreen({super.key, required this.week});

  final WeekSection? week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = week;
    return Scaffold(
      appBar: AppBar(title: const Text('This week')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: value == null || _total(value) == 0
                  ? _Empty(theme: theme)
                  : _Content(theme: theme, week: value),
            ),
          ),
        ),
      ),
    );
  }

  static int _total(WeekSection week) =>
      week.tasksDue + week.habitOccurrences;
}

class _Content extends StatelessWidget {
  const _Content({required this.theme, required this.week});

  final ThemeData theme;
  final WeekSection week;

  @override
  Widget build(BuildContext context) {
    final habitPct = week.habitOccurrences == 0
        ? 0.0
        : (week.habitCompletions / week.habitOccurrences)
              .clamp(0.0, 1.0)
              .toDouble();
    final taskPct = week.tasksDue == 0
        ? 0.0
        : (week.completedTasks / week.tasksDue).clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _rangeLabel(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _StatCard(
          theme: theme,
          title: 'Habits completed',
          value: '${(habitPct * 100).round()}%',
          detail:
              '${week.habitCompletions} of ${week.habitOccurrences} scheduled occurrences',
          progress: habitPct,
        ),
        const SizedBox(height: 10),
        _StatCard(
          theme: theme,
          title: 'Tasks completed',
          value: '${(taskPct * 100).round()}%',
          detail:
              '${week.completedTasks} of ${week.tasksDue} due or scheduled tasks',
          progress: taskPct,
        ),
        const SizedBox(height: 10),
        _StatCard(
          theme: theme,
          title: 'Days active',
          value: '${week.activeDays} / 7',
          detail: 'Days with a task or habit completion',
          progress: (week.activeDays / 7).clamp(0.0, 1.0).toDouble(),
        ),
        const SizedBox(height: 16),
        Text(
          'How this is calculated',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Habit completion = completed scheduled occurrences / scheduled occurrences (active habits only).\n'
          'Task completion = completed due-or-scheduled tasks / due-or-scheduled tasks.\n'
          'Active days = distinct local dates with a task completion or a valid habit completion.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  String _rangeLabel() {
    final start = week.start;
    final end = week.end;
    if (start == null || end == null) return 'This week';
    final fmt = DateFormat('d MMM');
    return '${fmt.format(start)} – ${fmt.format(end)}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.theme,
    required this.title,
    required this.value,
    required this.detail,
    required this.progress,
  });

  final ThemeData theme;
  final String title;
  final String value;
  final String detail;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              detail,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Text(
        'No weekly activity to show yet. Complete a task or habit and it will appear here.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
