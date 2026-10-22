import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'widgets.dart';

class LogFormScreen extends StatefulWidget {
  const LogFormScreen({
    super.key,
    required this.repository,
    this.initial,
  });

  final HealthRepository repository;
  final HealthLogEntry? initial;

  @override
  State<LogFormScreen> createState() => _LogFormScreenState();
}

class _LogFormScreenState extends State<LogFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _notesController;

  late DateTime _observedAt;

  /// `null` means "no severity selected" (the "None" segment).
  Severity? _severity;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final HealthLogEntry? initial = widget.initial;
    _observedAt = initial?.observedAt ?? DateTime.now();
    _severity = initial?.severity;
    _titleController = TextEditingController(text: initial?.title ?? '');
    _descriptionController =
        TextEditingController(text: initial?.description ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _validateTitle(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) {
      return 'Title is required';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final LogInput input = LogInput(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      observedAt: _observedAt,
      severity: _severity,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _saving = true);
    try {
      final String? id = widget.initial?.id;
      if (id == null) {
        await widget.repository.createLog(input);
      } else {
        await widget.repository.updateLog(id, input);
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
      title: widget.initial == null ? 'Add log' : 'Edit log',
      heading: widget.initial == null ? 'How are you feeling?' : 'Update this log',
      saving: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: formPadding,
          children: [
            HealthField(
              controller: _titleController,
              enabled: !_saving,
              maxLength: 120,
              label: 'Title',
              hint: 'e.g. Mild headache',
              validator: _validateTitle,
            ),
            HealthField(
              controller: _descriptionController,
              enabled: !_saving,
              maxLines: 3,
              maxLength: 1000,
              label: 'Description (optional)',
            ),
            DateTimeField(
              label: 'Observed at',
              value: _observedAt,
              onChanged: (value) => setState(() => _observedAt = value),
            ),
            FormSegmented<Severity?>(
              label: 'Severity',
              selected: _severity,
              options: [
                (null, 'None'),
                for (final Severity severity in Severity.values)
                  (severity, severityLabels[severity] ?? severity.wire),
              ],
              onChanged: (value) => setState(() => _severity = value),
            ),
            noteField(controller: _notesController, label: 'Notes (optional)'),
          ],
        ),
      ),
    );
  }
}