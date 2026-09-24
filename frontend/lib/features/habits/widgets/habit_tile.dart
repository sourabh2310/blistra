/// Reusable habit tile for today list.
library;

import 'package:flutter/material.dart';

import '../models.dart';

class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.habit,
    required this.onToggle,
    required this.onTap,
  });

  final HabitTodayResponse habit;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _TypeIcon(type: habit.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration:
                            habit.completedToday ? TextDecoration.lineThrough : null,
                        color: habit.completedToday
                            ? scheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    if (habit.description != null &&
                        habit.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        habit.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (habit.schedule != null) ...[
                      const SizedBox(height: 4),
                      _ScheduleBadge(schedule: habit.schedule!),
                    ],
                  ],
                ),
              ),
              Switch(
                value: habit.completedToday,
                onChanged: onToggle,
                activeThumbColor: scheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final HabitType type;

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;
    switch (type) {
      case HabitType.boolean:
        icon = Icons.check_circle;
        color = Colors.blue;
        break;
      case HabitType.count:
        icon = Icons.format_list_numbered;
        color = Colors.green;
        break;
      case HabitType.duration:
        icon = Icons.timer;
        color = Colors.orange;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      child: Icon(icon, color: color),
    );
  }
}

class _ScheduleBadge extends StatelessWidget {
  const _ScheduleBadge({required this.schedule});

  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    String text;
    if (schedule.frequency == HabitFrequency.daily) {
      text = 'Daily';
    } else {
      final List<String> days =
          schedule.daysOfWeek.map((String d) => d.substring(0, 3)).toList();
      text = 'Weekly: ${days.join(', ')}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}