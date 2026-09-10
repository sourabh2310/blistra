/// Create/edit schedule form page.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/auth/auth_state.dart';
import '../../core/api/api_client.dart';
import '../data/medicines_api_client.dart';
import '../models/medicine_enums.dart';
import '../state/schedule_form_controller.dart';

class ScheduleFormPage extends StatefulWidget {
  const ScheduleFormPage({
    super.key,
    required this.medicineId,
    this.schedule,
  });

  final String medicineId;
  final Schedule? schedule;

  @override
  State<ScheduleFormPage> createState() => _ScheduleFormPageState();
}

class _ScheduleFormPageState extends State<ScheduleFormPage> {
  final _formKey = GlobalKey<FormState>();
  late ScheduleFormController _controller;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final apiClient = context.read<ApiClient>();
      final authState = context.read<AuthState>();
      _controller = ScheduleFormController(
        MedicinesApiClient(tokenProvider: () => authState.apiClient.token ?? ''),
        medicineId: widget.medicineId,
        schedule: widget.schedule,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.schedule != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Schedule' : 'Add Schedule')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DropdownFormField<ScheduleType>(
              label: 'Schedule type *',
              value: _controller.scheduleType,
              items: ScheduleType.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(scheduleTypeLabel(s))))
                  .toList(),
              onChanged: (v) => _controller.setScheduleType(v!),
            ),
            const SizedBox(height: 16),
            if (_controller.scheduleType != ScheduleType.asNeeded) ...[
              _TimesField(controller: _controller),
              const SizedBox(height: 16),
            ],
            if (_controller.scheduleType == ScheduleType.weekly ||
                _controller.scheduleType == ScheduleType.customDays) ...[
              _DaysField(controller: _controller),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: _TextFormField(
                    label: 'Dose amount',
                    initialValue: _controller.doseAmount,
                    onChanged: _controller.setDoseAmount,
                    validator: (v) => _controller.errorFor('doseAmount'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TextFormField(
                    label: 'Unit',
                    initialValue: _controller.doseUnit,
                    onChanged: _controller.setDoseUnit,
                    validator: (v) => _controller.errorFor('doseUnit'),
                    maxLength: 25,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateFormField(
                    label: 'Start date',
                    value: _controller.startDate,
                    onChanged: _controller.setStartDate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _DateFormField(
                    label: 'End date',
                    value: _controller.endDate,
                    onChanged: _controller.setEndDate,
                    validator: (v) => _controller.errorFor('endDate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Active'),
              value: _controller.active,
              onChanged: _controller.setActive,
            ),
            const SizedBox(height: 24),
            if (_controller.hasErrors)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Please fix the highlighted fields',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEdit ? 'Save Changes' : 'Create Schedule'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _controller.save();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _TextFormField extends StatelessWidget {
  const _TextFormField({
    required this.label,
    this.initialValue = '',
    required this.onChanged,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      onChanged: onChanged,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _DropdownFormField<T> extends StatelessWidget {
  const _DropdownFormField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _TimesField extends StatelessWidget {
  const _TimesField({required this.controller});

  final ScheduleFormController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Times *', style: Theme.of(context).textTheme.titleSmall),
            TextButton.icon(
              onPressed: () => _pickTime(context),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (controller.times.isEmpty && controller.errorFor('times') != null)
          Text(
            controller.errorFor('times')!,
            style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
          ),
        Wrap(
          spacing: 8,
          children: controller.times
              .map((t) => Chip(
                    label: Text(t),
                    onDeleted: () => controller.setTimes(
                          controller.times.where((e) => e != t).toList(),
                        ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _pickTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final str =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      controller.setTimes([...controller.times, str]);
    }
  }
}

class _DaysField extends StatelessWidget {
  const _DaysField({required this.controller});

  final ScheduleFormController controller;

  @override
  Widget build(BuildContext context) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Days *', style: Theme.of(context).textTheme.titleSmall),
            if (controller.errorFor('daysOfWeek') != null)
              Text(
                controller.errorFor('daysOfWeek')!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
          ],
        ),
        Wrap(
          spacing: 8,
          children: List.generate(7, (i) {
            final index = i + 1;
            final selected = controller.daysOfWeek.contains(index);
            return FilterChip(
              label: Text(dayNames[i]),
              selected: selected,
              onSelected: (v) {
                final newList = List<int>.from(controller.daysOfWeek);
                if (v) {
                  newList.add(index);
                } else {
                  newList.remove(index);
                }
                controller.setDaysOfWeek(newList);
              },
            );
          }),
        ),
      ],
    );
  }
}

class _DateFormField extends StatelessWidget {
  const _DateFormField({
    required this.label,
    this.value,
    required this.onChanged,
    this.validator,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final FormFieldValidator<DateTime?>? validator;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
          errorText: validator?.call(value),
        ),
        child: Text(value == null ? 'Select date' : _formatDate(value!)),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}