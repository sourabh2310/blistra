/// Today screen showing active habits due today with completion toggles.
library;

import 'package:flutter/material.dart';

import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';
import '../widgets/habit_tile.dart';
import 'habit_detail_screen.dart';
import 'habit_form_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);

    if (controller.todayHabits.isEmpty) {
      return _EmptyState(
        message: 'No active habits due today.\nCreate a habit and add a schedule!',
        onAdd: () => _showCreateHabitSheet(context),
      );
    }

    final int total = controller.todayHabits.length;
    final int done = controller.doneToday.length;

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.todayHabits.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _TodaySummary(done: done, total: total);
        }
        final HabitTodayResponse habit = controller.todayHabits[index - 1];
        return HabitTile(
          habit: habit,
          onToggle: (bool completed) => _toggleCompletion(context, habit, completed),
          onTap: () => _openDetail(context, habit),
        );
      },
    );
  }

  Future<void> _toggleCompletion(
    BuildContext context,
    HabitTodayResponse habit,
    bool completed,
  ) async {
    final HabitsController controller = HabitsScope.of(context);
    // User-local calendar day: the backend compares against the user
    // timezone's today, so a UTC conversion here would record completions
    // on the wrong day around midnight.
    final DateTime today = DateTime.now();
    try {
      if (completed) {
        // already completed - remove
        await controller.removeCompletion(habit.id, today);
      } else {
        // record new completion
        await controller.recordCompletion(
          habit.id,
          completedOn: today,
          value: habit.type == HabitType.count ? '1' : null,
          durationMinutes: habit.type == HabitType.duration ? habit.targetMinutes : null,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(completed ? 'Completion removed' : 'Marked complete'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  void _openDetail(BuildContext context, HabitTodayResponse habit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HabitDetailScreen(habitId: habit.id),
      ),
    );
  }

  void _showCreateHabitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const HabitFormScreen(),
    );
  }
}

/// Factual "done / total" summary of today's occurrences, derived from the
/// loaded today list (never hardcoded, never placeholder habits).
class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.done, required this.total});

  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double progress = total == 0 ? 0 : done / total;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '$done / $total completed',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onAdd});

  final String message;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create Habit'),
            ),
          ],
        ),
      ),
    );
  }
}