/// Today screen showing active habits due today with completion toggles.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';
import '../widgets/habit_tile.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);
    final ThemeData theme = Theme.of(context);

    if (controller.todayHabits.isEmpty) {
      return _EmptyState(
        message: 'No active habits due today.\nCreate a habit and add a schedule!',
        onAdd: () => _showCreateHabitSheet(context),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.todayHabits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final HabitTodayResponse habit = controller.todayHabits[index];
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
    final DateTime today = DateTime.now().toUtc();
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