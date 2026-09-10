import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_exception.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'widgets.dart';

class ActivityFormScreen extends StatefulWidget {
  const ActivityFormScreen({
    super.key,
    required this.repository,
    this.initial,
  });

  final HealthRepository repository;
  final HealthActivity? initial;

  @override
  State<ActivityFormScreen> createState() => _ActivityFormScreenState();
}

class _ActivityFormScreenState extends State<ActivityFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _durationController;
  late final TextEditingController _distanceController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _notesController;

  late ActivityType _type;
  late DateTime _performedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final HealthActivity? initial = widget.initial;
    _type = initial?.type ?? ActivityType.walking;
    _performedAt = initial?.performedAt ?? DateTime.now();
    _durationController = TextEditingController(
        text: initial?.durationMinutes == null
            ? ''
            : '${initial!.durationMinutes}');
    _distanceController = TextEditingController(
        text: initial?.distanceKm == null ? '' : formatDouble(initial!.distanceKm!));
    _caloriesController = TextEditingController(
        text: initial?.caloriesBurned == null
            ? ''
            : '${initial!.caloriesBurned}');
    _notesController = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _durationController.dispose();
    _distanceController.dispose();
    _caloriesController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final int? duration = _optionalInt(_durationController.text);
    final double? distance = _optionalDouble(_distanceController.text);
    final int? calories = _optionalInt(_caloriesController.text);

    final ActivityInput input = ActivityInput(
      type: _type,
      performedAt: _performedAt,
      durationMinutes: duration,
      distanceKm: distance,
      caloriesBurned: calories,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _saving = true);
    try {
      final String? id = widget.initial?.id;
      if (id == null) {
        await widget.repository.createActivity(input);
      } else {
        await widget.repository.updateActivity(id, input);
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

  int? _optionalInt(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  double? _optionalDouble(String raw) {
    final String value = raw.trim();
    if (value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  String? _validateOptionalInt(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    return int.tryParse(value) == null ? 'Enter a whole number' : null;
  }

  String? _validateOptionalDouble(String? raw) {
    final String value = (raw ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    return double.tryParse(value) == null ? 'Enter a number' : null;
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.initial == null ? 'Add activity' : 'Edit activity',
      saving: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LabeledDropdown<ActivityType>(
              label: 'Type',
              value: _type,
              items: [
                for (final ActivityType type in ActivityType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(activityTypeLabels[type] ?? type.name),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'Performed at',
              value: _performedAt,
              onChanged: (value) => setState(() => _performedAt = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _durationController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
              ),
              validator: _validateOptionalInt,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _distanceController,
              enabled: !_saving,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Distance (km)',
                border: OutlineInputBorder(),
              ),
              validator: _validateOptionalDouble,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _caloriesController,
              enabled: !_saving,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Calories burned',
                border: OutlineInputBorder(),
              ),
              validator: _validateOptionalInt,
            ),
            const SizedBox(height: 16),
            noteField(controller: _notesController, label: 'Notes (optional)'),
          ],
        ),
      ),
    );
  }
}