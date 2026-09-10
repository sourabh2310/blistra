import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../../../core/api/api_exception.dart';
import '../formats.dart';
import '../models/planner_event.dart';
import '../planner_controller.dart';

/// Create or edit a simple time-blocked event. Editing re-submits every field
/// (the backend PUT is a full replacement).
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, required this.planner, this.event});

  final PlannerController planner;
  final PlannerEvent? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _location;
  late DateTime _start;
  late DateTime _end;
  bool _saving = false;

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _location = TextEditingController(text: event?.location ?? '');
    final now = DateTime.now().toLocal();
    DateTime start;
    DateTime end;
    if (event != null) {
      start = event.startAt.toLocal();
      end = event.endAt.toLocal();
    } else {
      start = DateTime(now.year, now.month, now.day, now.hour, now.minute)
          .add(const Duration(minutes: 30));
      end = start.add(const Duration(hours: 1));
    }
    _start = start;
    _end = end;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.planner.updateEvent(
          widget.event!.id,
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          startAt: _start,
          endAt: _end,
        );
      } else {
        await widget.planner.createEvent(
          title: _title.text.trim(),
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          startAt: _start,
          endAt: _end,
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit event' : 'New event'),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: const Text('Save')),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _location,
              textInputAction: TextInputAction.next,
              maxLength: 255,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _description,
              minLines: 2,
              maxLines: 4,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickStart(context),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: Text('Start ${Formats.dateTime(_start)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickEnd(context),
                    icon: const Icon(Icons.stop, size: 18),
                    label: Text('End ${Formats.dateTime(_end)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isEditing ? 'Save changes' : 'Create event'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart(BuildContext context) async {
    final picked = await _pickDateTime(context, _start);
    if (picked == null) {
      return;
    }
    setState(() {
      _start = picked;
      if (_end.isBefore(_start) || _end == _start) {
        _end = _start.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEnd(BuildContext context) async {
    final picked = await _pickDateTime(context, _end);
    if (picked == null) {
      return;
    }
    if (!picked.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _end = picked);
  }

  Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) {
      return null;
    }
    final existing = initial;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: existing.hour, minute: existing.minute),
    );
    if (time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}