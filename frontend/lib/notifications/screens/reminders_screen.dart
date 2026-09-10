import 'package:flutter/material.dart';
import 'package:frontend/notifications/models/reminder.dart';
import 'package:frontend/notifications/models/reminder_type.dart';
import 'package:intl/intl.dart';

import '../state/reminders_controller.dart';
import 'reminder_form_screen.dart';

/// Lists the current user's active reminders, allows creating new GENERAL
/// reminders and cancelling/editing existing ones. Pull-to-refresh also
/// re-synchronizes local notifications.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({
    super.key,
    required this.onRefresh,
  });

  /// Invoked after local mutation refreshes to re-sync scheduled notifications.
  final Future<void> Function() onRefresh;

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _dateFormatter = DateFormat('EEE, MMM d · HH:mm');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<RemindersController>().load();
    await widget.onRefresh();
  }

  Future<void> _createOrEdit([Reminder? existing]) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReminderFormScreen(existing: existing),
      ),
    );
    if (created == true) {
      await _load();
    }
  }

  Future<void> _cancel(Reminder reminder) async {
    await context.read<RemindersController>().cancel(reminder.id);
    await widget.onRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder cancelled')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RemindersController>();

    return RefreshIndicator(
      onRefresh: _load,
      child: controller.loading && controller.reminders.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : controller.reminders.isEmpty
              ? _emptyState(context)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: controller.reminders.length,
                  itemBuilder: (context, index) {
                    final reminder = controller.reminders[index];
                    return Dismissible(
                      key: ValueKey(reminder.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Theme.of(context).colorScheme.errorContainer,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        child: Icon(Icons.delete_outline,
                            color:
                                Theme.of(context).colorScheme.onErrorContainer),
                      ),
                      confirmDismiss: (_) async => true,
                      onDismissed: (_) => _cancel(reminder),
                      child: ListTile(
                        leading:
                            Icon(_iconFor(reminder.type), size: 28),
                        title: Text(reminder.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '${_dateFormatter.format(reminder.scheduledAt.toLocal())}'
                          ' · ${controller.labelFor(reminder.type)}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _createOrEdit(reminder),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.notifications_none,
          size: 56,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        const Center(child: Text('No upcoming reminders')),
        const SizedBox(height: 8),
        const Center(
          child: Text('Tap + to add a reminder'),
        ),
      ],
    );
  }

  IconData _iconFor(ReminderType type) => switch (type) {
        ReminderType.medicine => Icons.medication_outlined,
        ReminderType.habit => Icons.repeat_outlined,
        ReminderType.planner => Icons.event_note_outlined,
        ReminderType.health => Icons.favorite_outline,
        ReminderType.general => Icons.alarm,
      };
}