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

  /// `null` means "no severity selected". Choosing a label sets the wire value;
  /// the dropdown itself is driven by strings so "None" maps back to null.
  Severity? _severity;
  bool _saving = false;

  static const String _noneLabel = 'None';

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

  String get _severityLabel => _severity == null
      ? _noneLabel
      : severityLabels[_severity] ?? _severity!.wire;

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
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: _validateTitle,
            ),
            TextFormField(
              controller: _descriptionController,
              enabled: !_saving,
              maxLines: 3,
              maxLength: 1000,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            DateTimeField(
              label: 'Observed at',
              value: _observedAt,
              onChanged: (value) => setState(() => _observedAt = value),
            ),
            const SizedBox(height: 16),
            LabeledDropdown<String>(
              label: 'Severity',
              value: _severityLabel,
              items: [
                const DropdownMenuItem(value: _noneLabel, child: Text(_noneLabel)),
                for (final Severity severity in Severity.values)
                  DropdownMenuItem(
                    value: severityLabels[severity] ?? severity.wire,
                    child: Text(severityLabels[severity] ?? severity.wire),
                  ),
              ],
              onChanged: (label) {
                if (label == null) {
                  return;
                }
                setState(() {
                  _severity = label == _noneLabel
                      ? null
                      : Severity.values.firstWhere(
                          (severity) =>
                              (severityLabels[severity] ?? severity.wire) == label,
                        );
                });
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