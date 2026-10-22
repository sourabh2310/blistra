import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/page_header.dart';
import '../formats.dart';
import '../models/planner_event.dart';
import '../planner_controller.dart';
import '../widgets/planner_parts.dart';

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
    _title = TextEditingController(text: event?.title ?? '')
      ..addListener(() => setState(() {}));
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
          SnackBar(content: Text(_friendly(e))),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save this event. Try again.")),
        );
      }
    }
  }

  String _friendly(ApiException error) {
    if (error.fieldErrors.isNotEmpty) return error.fieldErrors.values.first;
    if (error.message == 'Request validation failed') {
      return "Couldn't save this event. Try again.";
    }
    return error.message.isEmpty ? "Couldn't save this event. Try again." : error.message;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        bottomNavigationBar: StickyActionBar(
          label: _isEditing ? 'Save changes' : 'Create event',
          busy: _saving,
          onPressed: _title.text.trim().isEmpty ? null : _save,
        ),
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 24),
              children: [
                BlistraPageHeader(
                  eyebrow: _isEditing ? 'Edit event' : 'New event',
                  title: _isEditing ? 'Update this event' : "What's happening?",
                  showAvatar: false,
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
                ),
                PlannerTextField(
                  label: 'Title',
                  controller: _title,
                  hint: 'Team sync',
                  large: true,
                  autofocus: !_isEditing,
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Title is required' : null,
                ),
                Row(
                  children: [
                    Expanded(
                      child: PickerField(
                        label: 'Starts',
                        value: _pickerLabel(_start),
                        onTap: _saving ? null : () => _pickStart(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PickerField(
                        label: 'Ends',
                        value: _pickerLabel(_end),
                        onTap: _saving ? null : () => _pickEnd(context),
                      ),
                    ),
                  ],
                ),
                PlannerTextField(
                  label: 'Location',
                  controller: _location,
                  hint: 'Optional',
                  maxLength: 255,
                  textInputAction: TextInputAction.next,
                ),
                PlannerTextField(
                  label: 'Notes',
                  controller: _description,
                  hint: 'Optional',
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 2000,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _pickerLabel(DateTime value) =>
      '${PlannerDates.relative(value)} · ${Formats.timeOfDay(value)}';

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
    if (!context.mounted) return;
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
    if (!context.mounted) return null;
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