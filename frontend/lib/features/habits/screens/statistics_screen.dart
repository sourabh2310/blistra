/// Statistics screen showing streak and completion data for a habit.
library;

import 'package:flutter/material.dart';

import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);

    if (controller.activeHabits.isEmpty) {
      return _EmptyState(
        message: 'No active habits to show statistics for.',
        onAdd: () => _showCreateHabitSheet(context),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: controller.activeHabits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (BuildContext context, int index) {
        final Habit habit = controller.activeHabits[index];
        return _StatisticsCard(habitId: habit.id, habitName: habit.name);
      },
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

class _StatisticsCard extends StatefulWidget {
  const _StatisticsCard({required this.habitId, required this.habitName});

  final String habitId;
  final String habitName;

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
    final HabitsController controller = HabitsScope.of(context);
    try {
      final HabitStatisticsResponse stats =
          await controller.fetchStatistics(widget.habitId);
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
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.habitName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text('Error: $_error', style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ))
            else if (_stats != null) ...[
              _StatRow(
                label: 'Current Streak',
                value: '${_stats!.currentStreak}',
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              _StatRow(
                label: 'Best Streak',
                value: '${_stats!.bestStreak}',
                icon: Icons.emoji_events,
                color: Colors.amber,
              ),
              const SizedBox(height: 8),
              _StatRow(
                label: 'Total Completions',
                value: '${_stats!.totalCompletions}',
                icon: Icons.check_circle_outline,
                color: Colors.green,
              ),
              const SizedBox(height: 8),
              _StatRow(
                label: 'Last Completed',
                value: _stats!.lastCompletedOn != null
                    ? DateFormat('MMM d, yyyy').format(
                        _stats!.lastCompletedOn!.toLocal())
                    : 'Never',
                icon: Icons.calendar_today,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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
              Icons.show_chart_outlined,
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