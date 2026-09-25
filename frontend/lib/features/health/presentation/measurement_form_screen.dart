import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/api/api_exception.dart';
import '../health_models.dart';
import '../health_repository.dart';
import 'widgets.dart';

class MeasurementFormScreen extends StatefulWidget {
  const MeasurementFormScreen({
    super.key,
    required this.repository,
    this.initial,
    this.initialType,
  });

  final HealthRepository repository;
  final HealthMeasurement? initial;

  /// Prefills the type picker when creating (ignored when editing).
  final MeasurementType? initialType;

  @override
  State<MeasurementFormScreen> createState() => _MeasurementFormScreenState();
}

class _MeasurementFormScreenState extends State<MeasurementFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _valueController;
  late final TextEditingController _diastolicController;
  late final TextEditingController _sourceController;
  late final TextEditingController _notesController;

  late MeasurementType _type;
  late String _unit;
  late DateTime _measuredAt;
  bool _saving = false;

  bool get _isBloodPressure => _type == MeasurementType.bloodPressure;

  @override
  void initState() {
    super.initState();
    final HealthMeasurement? initial = widget.initial;
    _type = initial?.type ?? widget.initialType ?? MeasurementType.weight;
    _unit = initial?.unit ?? defaultUnitFor(_type);
    _measuredAt = initial?.measuredAt ?? DateTime.now();
    _valueController =
        TextEditingController(text: initial == null ? '' : formatDouble(initial.value));
    _diastolicController = TextEditingController(
        text: initial?.valueDiastolic == null
            ? ''
            : formatDouble(initial!.valueDiastolic));
    _sourceController = TextEditingController(text: initial?.source ?? '');
    _notesController = TextEditingController(text: initial?.notes ?? '');
  }

  @override
  void dispose() {
    _valueController.dispose();
    _diastolicController.dispose();
    _sourceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onTypeChanged(MeasurementType? type) {
    if (type == null) {
      return;
    }
    setState(() {
      _type = type;
      if (!unitsFor(type).contains(_unit)) {
        _unit = defaultUnitFor(type);
      }
    });
  }

  String? _validatePositive(String? value) {
    final double? parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) {
      return 'Enter a value greater than zero';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final double value = double.parse(_valueController.text.trim());
    final double? diastolic = _isBloodPressure
        ? double.tryParse(_diastolicController.text.trim())
        : null;
    if (_isBloodPressure && (diastolic == null || diastolic <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Diastolic value must be greater than zero')),
      );
      return;
    }
    if (_isBloodPressure && value <= diastolic!) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Systolic must be greater than diastolic')),
      );
      return;
    }

    final MeasurementInput input = MeasurementInput(
      type: _type,
      measuredAt: _measuredAt,
      value: value,
      valueDiastolic: diastolic,
      unit: _unit,
      source: _sourceController.text.trim().isEmpty
          ? null
          : _sourceController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    setState(() => _saving = true);
    try {
      final String? id = widget.initial?.id;
      if (id == null) {
        await widget.repository.createMeasurement(input);
      } else {
        await widget.repository.updateMeasurement(id, input);
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
      title: widget.initial == null ? 'Add measurement' : 'Edit measurement',
      saving: _saving,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            LabeledDropdown<MeasurementType>(
              label: 'Type',
              value: _type,
              items: [
                for (final MeasurementType type in MeasurementType.values)
                  DropdownMenuItem(
                    value: type,
                    child: Text(measurementTypeLabels[type] ?? type.name),
                  ),
              ],
              onChanged: _onTypeChanged,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _valueController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: _isBloodPressure ? 'Systolic' : 'Value',
                border: const OutlineInputBorder(),
              ),
              validator: _validatePositive,
            ),
            if (_isBloodPressure) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _diastolicController,
                enabled: !_saving,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Diastolic',
                  border: OutlineInputBorder(),
                ),
                validator: _validatePositive,
              ),
            ],
            const SizedBox(height: 16),
            LabeledDropdown<String>(
              label: 'Unit',
              value: _unit,
              items: [
                for (final String unit in unitsFor(_type))
                  DropdownMenuItem(value: unit, child: Text(unit)),
              ],
              onChanged: (unit) {
                if (unit != null) {
                  setState(() => _unit = unit);
                }
              },
            ),
            const SizedBox(height: 16),
            DateTimeField(
              label: 'Measured at',
              value: _measuredAt,
              onChanged: (value) => setState(() => _measuredAt = value),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sourceController,
              enabled: !_saving,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: 'Source (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            noteField(controller: _notesController, label: 'Notes (optional)'),
          ],
        ),
      ),
    );
  }
}