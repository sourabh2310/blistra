import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'widgets.dart';

class AppointmentFormScreen extends StatefulWidget {
  const AppointmentFormScreen({
    super.key,
    required this.repository,
    this.initial,
  });

  final HealthRepository repository;
  final HealthAppointment? initial;

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;

  late AppointmentStatus? _status;
  late DateTime _scheduledAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final HealthAppointment? initial = widget.initial;
    _scheduledAt = initial?.scheduledAt ?? DateTime.now().add(const Duration(days: 1));
    _status = initial?.status ?? AppointmentStatus.scheduled;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _locationController = TextEditingController(text: initial?.location ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final AppointmentInput input = AppointmentInput(
      title: _titleController.text.trim(),
      scheduledAt: _scheduledAt,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      status: _status,
    );

    setState(() => _saving = true);
    try {
      final String? id = widget.initial?.id;
      if (id == null) {
        await widget.repository.createAppointment(input);
      } else {
        await widget.repository.updateAppointment(id, input);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        showError(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.initial == null ? 'Add appointment' : 'Edit appointment',
      saving: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              enabled: !_saving,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'Scheduled at',
              value: _scheduledAt,
              onChanged: (value) => setState(() => _scheduledAt = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              enabled: !_saving,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            LabeledDropdown<AppointmentStatus>(
              label: 'Status',
              value: _status ?? AppointmentStatus.scheduled,
              items: [
                for (final AppointmentStatus status in AppointmentStatus.values)
                  DropdownMenuItem(
                    value: status,
                    child: Text(appointmentStatusLabels[status] ?? status.wire),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 16),
            noteField(controller: _notesController, label: 'Notes (optional)'),
          ],
        ),
      ),
    );
  }
}