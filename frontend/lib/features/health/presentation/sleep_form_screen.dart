import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'widgets.dart';

class SleepFormScreen extends StatefulWidget {
  const SleepFormScreen({
    super.key,
    required this.repository,
    this.initial,
  });

  final HealthRepository repository;
  final HealthSleepRecord? initial;

  @override
  State<SleepFormScreen> createState() => _SleepFormScreenState();
}

class _SleepFormScreenState extends State<SleepFormScreen> {
  late final TextEditingController _notesController;

  late DateTime _startedAt;
  late DateTime _endedAt;
  late int _rating;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final HealthSleepRecord? initial = widget.initial;
    final DateTime now = DateTime.now();
    _startedAt = initial?.startedAt ?? now.subtract(const Duration(hours: 8));
    _endedAt = initial?.endedAt ?? now;
    _rating = initial?.rating ?? 3;
    _notesController = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_endedAt.isBefore(_startedAt)) {
      showError(
        context,
        ApiException(400, 'BAD_REQUEST', 'End time must be after start time'),
      );
      return;
    }
    final SleepInput input = SleepInput(
      startedAt: _startedAt,
      endedAt: _endedAt,
      rating: _rating,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    setState(() => _saving = true);
    try {
      final String? id = widget.initial?.id;
      if (id == null) {
        await widget.repository.createSleep(input);
      } else {
        await widget.repository.updateSleep(id, input);
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
      title: widget.initial == null ? 'Add sleep' : 'Edit sleep',
      saving: _saving,
      onSave: _save,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DateTimeField(
            label: 'Started at',
            value: _startedAt,
            onChanged: (value) => setState(() => _startedAt = value),
          ),
          const SizedBox(height: 8),
          DateTimeField(
            label: 'Ended at',
            value: _endedAt,
            onChanged: (value) => setState(() => _endedAt = value),
          ),
          const SizedBox(height: 16),
          LabeledDropdown<int>(
            label: 'Feeling on waking (1–5)',
            value: _rating,
            items: [
              for (int i = 1; i <= 5; i++)
                DropdownMenuItem(value: i, child: Text('$i')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _rating = value);
              }
            },
          ),
          const SizedBox(height: 16),
          noteField(controller: _notesController, label: 'Notes (optional)'),
        ],
      ),
    );
  }
}