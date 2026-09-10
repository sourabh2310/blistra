/// Habit detail screen with completions history and statistics.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      await Future.wait([
        _loadHabit(controller),
        _loadSchedule(controller),
        _loadCompletions(controller),
        _loadStats(controller),
      ]);
      if (mounted) {
        setState(() => _loading = false);
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

  Future<void> _loadCompletions(HabitsController controller) async {
    final PageResult<Completion> result =
        await controller.api.fetchCompletions(widget.habitId, size: 100);
    _completions = result.items;
  }

  Future<void> _loadStats(HabitsController controller) async {
    _stats = await controller.fetchStatistics(widget.habitId);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Habit Detail')),
        body: Center(child: Text('Error: $_error')),
      );
    }

    final Habit habit = _habit!;

    return Scaffold(
      appBar: AppBar(
        title: Text(habit.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showEditSheet(context),
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'archive':
                  _archive(context);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              if (!habit.isArchived)
                const PopupMenuItem(
                  value: 'archive',
                  child: Text('Archive'),
                ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _HeaderCard(habit: habit, schedule: _schedule),
            const SizedBox(height: 16),
            _StatisticsSummary(stats: _stats),
            const SizedBox(height: 16),
            _CompletionsList(
              completions: _completions,
              habitType: habit.type,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HabitFormScreen(existingHabit: _habit!),
    ).then((_) => _load());
  }

  Future<void> _archive(BuildContext context) async {
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

    final HabitsController controller = HabitsScope.of(context);
    try {
      await controller.archiveHabit(_habit!.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit archived')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.habit, required this.schedule});

  final Habit habit;
  final Schedule? schedule;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _typeIcon(habit.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit.type.name.toUpperCase(),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        habit.status.name.toUpperCase(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (habit.description != null && habit.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(habit.description!, style: theme.textTheme.bodyMedium),
            ],
            if (schedule != null) ...[
              const SizedBox(height: 12),
              _ScheduleSummary(schedule: schedule!),
            ],
            if (habit.targetValue != null || habit.targetMinutes != null) ...[
              const SizedBox(height: 12),
              _TargetSummary(habit: habit),
            ],
          ],
        ),
      ),
    );
  }

  Widget _typeIcon(HabitType type) {
    switch (type) {
      case HabitType.boolean:
        return const CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.check, color: Colors.white),
        );
      case HabitType.count:
        return const CircleAvatar(
          backgroundColor: Colors.green,
          child: Icon(Icons.format_list_numbered, color: Colors.white),
        );
      case HabitType.duration:
        return const CircleAvatar(
          backgroundColor: Colors.orange,
          child: Icon(Icons.timer, color: Colors.white),
        );
    }
  }
}

class _ScheduleSummary extends StatelessWidget {
  const _ScheduleSummary({required this.schedule});

  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    String description;
    if (schedule.frequency == HabitFrequency.daily) {
      description = 'Daily';
    } else {
      final List<String> days =
          schedule.daysOfWeek.map((String d) => d.substring(0, 3)).toList();
      description = 'Weekly on ${days.join(', ')}';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.repeat,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _TargetSummary extends StatelessWidget {
  const _TargetSummary({required this.habit});

  final Habit habit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> parts = [];

    if (habit.targetValue != null) {
      parts.add('Target: ${habit.targetValue} ${habit.targetUnit ?? ''}');
    }
    if (habit.targetMinutes != null) {
      parts.add('Target: ${habit.targetMinutes} min');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(parts.join(' • '), style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatisticsSummary extends StatelessWidget {
  const _StatisticsSummary({required this.stats});

  final HabitStatisticsResponse? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistics', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Current Streak',
                    value: '${stats!.currentStreak}',
                    icon: Icons.local_fire_department,
                    color: Colors.orange,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Best Streak',
                    value: '${stats!.bestStreak}',
                    icon: Icons.emoji_events,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    label: 'Total Completions',
                    value: '${stats!.totalCompletions}',
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    label: 'Last Completed',
                    value: stats!.lastCompletedOn != null
                        ? DateFormat('MMM d').format(
                            stats!.lastCompletedOn!.toLocal())
                        : 'Never',
                    icon: Icons.calendar_today,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(label, style: theme.textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 4),
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

class _CompletionsList extends StatelessWidget {
  const _CompletionsList({
    required this.completions,
    required this.habitType,
  });

  final List<Completion> completions;
  final HabitType habitType;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (completions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'No completions yet',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('History', style: theme.textTheme.titleMedium),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: completions.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: theme.dividerColor,
            ),
            itemBuilder: (BuildContext context, int index) {
              final Completion c = completions[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text(
                    DateFormat('d').format(c.completedOn.toLocal()),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                title: Text(
                  DateFormat('EEEE, MMM d, yyyy').format(c.completedOn.toLocal()),
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: _completionSubtitle(c),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget? _completionSubtitle(Completion c) {
    switch (habitType) {
      case HabitType.count:
        if (c.value != null) {
          return Text('Quantity: ${c.value}');
        }
        return null;
      case HabitType.duration:
        if (c.durationMinutes != null) {
          return Text('${c.durationMinutes} min');
        }
        return null;
      case HabitType.boolean:
        return null;
    }
  }
}