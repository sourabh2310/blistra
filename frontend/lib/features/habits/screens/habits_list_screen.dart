/// List of all user habits with create, edit, archive actions.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../habit_insights.dart';
import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';
import 'habit_detail_screen.dart';
import 'habit_form_screen.dart';

class HabitsListScreen extends StatelessWidget {
  const HabitsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HabitsController controller = HabitsScope.of(context);

    if (controller.habits.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
        children: [
          PagePad(
            EmptyCard(
              message: 'No habits yet. Create your first habit to get started.',
              action: 'Create habit',
              onAction: () => showHabitFormSheet(context),
            ),
          ),
        ],
      );
    }

    final List<(String, List<Habit>)> groups = [
      for (final HabitStatus status in HabitStatus.values)
        (
          habitStatusLabel(status),
          controller.habits.where((Habit h) => h.status == status).toList(),
        ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
      children: [
        for (final (String label, List<Habit> habits) in groups)
          if (habits.isNotEmpty) ...[
            SectionHeader(title: label, actionLabel: '${habits.length}'),
            PagePad(
              GlassList(
                children: [
                  for (final Habit habit in habits)
                    _HabitListTile(
                      habit: habit,
                      onTap: () => _openDetail(context, habit),
                      onEdit: () =>
                          showHabitFormSheet(context, existingHabit: habit),
                      onArchive: () => _archiveHabit(context, habit),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
      ],
    );
  }

  void _openDetail(BuildContext context, Habit habit) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HabitDetailScreen(habitId: habit.id),
      ),
    );
  }

  Future<void> _archiveHabit(BuildContext context, Habit habit) async {
    final HabitsController controller = HabitsScope.of(context);
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
    final colors = BlistraColors.resolve(context);

    return GlassRow(
      leading: IconWell(
        habitTypeIcon(habit.type),
        color: habit.isActive ? colors.accentText : null,
      ),
      title: habit.name,
      subtitle: _subtitle(habit),
      done: habit.isArchived,
      onTap: onTap,
      trailing: PopupMenuButton<String>(
        tooltip: 'More',
        icon: Icon(Icons.more_horiz_rounded, color: colors.muted, size: 20),
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
    );
  }

  String _subtitle(Habit habit) {
    final List<String> parts = [
      habitTypeLabel(habit.type),
      ?habitTargetLabel(
        targetValue: habit.targetValue,
        targetUnit: habit.targetUnit,
        targetMinutes: habit.targetMinutes,
      ),
    ];
    return parts.join(' · ');
  }
}
