import 'package:flutter/material.dart';
import 'package:frontend/features/notifications/models/reminder.dart';
import 'package:frontend/features/notifications/models/reminder_type.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../state/reminders_controller.dart';

/// Create or edit a GENERAL reminder. Editing a domain reminder is not
/// allowed, matching the backend contract (only GENERAL reminders are
/// client-managed).
class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.existing});

  final Reminder? existing;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  static const _timezones = <String>[
    'UTC',
    'America/New_York',
    'America/Los_Angeles',
    'Europe/London',
    'Europe/Berlin',
    'Asia/Kolkata',
    'Asia/Singapore',
    'Asia/Tokyo',
    'Australia/Sydney',
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _saving = false;

  late DateTime _scheduledAt;
  late String _timezone;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _titleController.text = existing?.title ?? '';
    _bodyController.text = existing?.body ?? '';
    _scheduledAt = (existing?.scheduledAt ?? DateTime.now().add(
            const Duration(hours: 1)))
        .toLocal();
    _timezone = _resolveTimezone(existing?.timezone);
  }

  String _resolveTimezone(String? configured) {
    if (configured != null && configured.isNotEmpty) {
      return _timezones.contains(configured) ? configured : 'UTC';
    }
    final offset = DateTime.now().timeZoneOffset;
    const byOffset = <String, String>{
      '+05:30': 'Asia/Kolkata',
      '+08:00': 'Asia/Singapore',
    };
    return byOffset[offset.toString()] ?? 'UTC';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledAt),
    );
    if (time == null) return;

    setState(() {
      _scheduledAt = DateTime(date.year, date.month, date.day, time.hour,
          time.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final scheduledAtUtc = _scheduledAt.toUtc();
    if (!scheduledAtUtc.isAfter(DateTime.now().toUtc())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder time must be in the future')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    final controller = context.read<RemindersController>();
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (_isEditing) {
      await controller.update(
        widget.existing!.id,
        title: title,
        body: body.isEmpty ? null : body,
        scheduledAtUtc: scheduledAtUtc,
        timezone: _timezone,
      );
    } else {
      await controller.create(
        title: title,
        body: body.isEmpty ? null : body,
        scheduledAtUtc: scheduledAtUtc,
        timezone: _timezone,
      );
    }

    if (mounted) {
      final error = controller.error;
      if (error != null) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDomain = _isEditing && widget.existing!.type.isDomainType;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit reminder' : 'New reminder'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isDomain)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'This reminder is managed by ${_domainName(widget.existing!.type)} and cannot be edited here.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else ...[
                TextFormField(
                  controller: _titleController,
                  enabled: !isDomain,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Title is required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  enabled: !isDomain,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: const Text('When'),
                  subtitle: Text(DateFormat('EEE, MMM d, yyyy · HH:mm')
                      .format(_scheduledAt)),
                  onTap: isDomain ? null : _pickDateTime,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _timezone,
                  decoration: const InputDecoration(
                    labelText: 'Timezone',
                    border: OutlineInputBorder(),
                  ),
                  items: _timezones
                      .map((tz) => DropdownMenuItem(value: tz, child: Text(tz)))
                      .toList(),
                  onChanged: isDomain
                      ? null
                      : (value) => setState(() => _timezone = value ?? 'UTC'),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _saving || isDomain ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Create reminder'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _domainName(ReminderType type) => switch (type) {
        ReminderType.medicine => 'Medicine',
        ReminderType.habit => 'Habits',
        ReminderType.planner => 'Planner',
        ReminderType.health => 'Health',
        ReminderType.general => 'Blistra',
      };
}