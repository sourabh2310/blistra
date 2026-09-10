/// List of all user habits with create, edit, archive actions.
library;

import 'package:flutter/material.dart';

import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';
import '../widgets/habit_tile.dart';
import 'habit_form_screen.dart';

class HabitsListScreen extends StatelessWidget {
  const HabitsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);

    if (controller.habits.isEmpty) {
      return _EmptyState(onAdd: () => _showCreateHabitSheet(context));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.habits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final Habit habit = controller.habits[index];
        return _HabitListTile(
          habit: habit,
          onTap: () => _openDetail(context, habit),
          onEdit: () => _showEditHabitSheet(context, habit),
          onArchive: () => _archiveHabit(context, habit),
        );
      },
    );
  }

  void _openDetail(BuildContext context, Habit habit) {
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

  void _showEditHabitSheet(BuildContext context, Habit habit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HabitFormScreen(existingHabit: habit),
    );
  }

  Future<void> _archiveHabit(BuildContext context, Habit habit) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Archive habit?'),
        content: Text('"${habit.name}" will be hidden from active lists. '
            'Completion history will be kept.'),
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

    final HabitsController controller = HabitsScope.of(context);
    try {
      await controller.archiveHabit(habit.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit archived')),
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
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

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
              Icons.track_changes_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No habits yet.\nCreate your first habit to get started.',
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

class _HabitListTile extends StatelessWidget {
  const _HabitListTile({
    required this.habit,
    required this.onTap,
    required this.onEdit,
    required this.onArchive,
  });

  final Habit habit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: ListTile(
        leading: _statusIcon(habit),
        title: Text(
          habit.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: habit.isArchived ? scheme.onSurfaceVariant : null,
          ),
        ),
        subtitle: Text(
          _subtitle(habit),
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (String value) {
            switch (value) {
              case 'edit':
                onEdit();
                break;
              case 'archive':
                onArchive();
                break;
            }
          },
          itemBuilder: (BuildContext context) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(
              value: 'archive',
              enabled: !habit.isArchived,
              child: const Text('Archive'),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _statusIcon(Habit habit) {
    switch (habit.type) {
      case HabitType.boolean:
        return const Icon(Icons.check_circle_outline);
      case HabitType.count:
        return const Icon(Icons.format_list_numbered);
      case HabitType.duration:
        return const Icon(Icons.timer_outlined);
    }
  }

  String _subtitle(Habit habit) {
    final List<String> parts = [
      habit.type.name.toUpperCase(),
      habit.status.name.toUpperCase(),
    ];
    if (habit.targetValue != null) {
      parts.add('Target: ${habit.targetValue} ${habit.targetUnit ?? ''}');
    }
    if (habit.targetMinutes != null) {
      parts.add('Target: ${habit.targetMinutes} min');
    }
    return parts.join(' • ');
  }
}