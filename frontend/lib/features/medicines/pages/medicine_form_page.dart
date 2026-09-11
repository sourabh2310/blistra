/// Create/edit medicine form page.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/api/api_client.dart';
import '../data/medicines_api_client.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../state/medicine_form_controller.dart';

class MedicineFormPage extends StatefulWidget {
  const MedicineFormPage({super.key, this.medicine});

  final Medicine? medicine;

  @override
  State<MedicineFormPage> createState() => _MedicineFormPageState();
}

class _MedicineFormPageState extends State<MedicineFormPage> {
  final _formKey = GlobalKey<FormState>();
  late MedicineFormController _controller;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final apiClient = context.read<ApiClient>();
      final authState = context.read<AuthState>();
      _controller = MedicineFormController(
        MedicinesApiClient(
          tokenProvider: () => authState.apiClient.token ?? '',
          onUnauthorized: () => authState.handleUnauthorized(),
        ),
        medicine: widget.medicine,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Medicine' : 'Add Medicine'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TextFormField(
              label: 'Name *',
              initialValue: _controller.name,
              onChanged: _controller.setName,
              validator: (v) => _controller.errorFor('name'),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            _TextFormField(
              label: 'Generic name',
              initialValue: _controller.genericName,
              onChanged: _controller.setGenericName,
              validator: (v) => _controller.errorFor('genericName'),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            _TextFormField(
              label: 'Form (tablet, capsule, syrup, etc.)',
              initialValue: _controller.form,
              onChanged: _controller.setForm,
              validator: (v) => _controller.errorFor('form'),
              maxLength: 50,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TextFormField(
                    label: 'Strength',
                    initialValue: _controller.strength,
                    onChanged: _controller.setStrength,
                    validator: (v) => _controller.errorFor('strength'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TextFormField(
                    label: 'Unit (mg, ml, etc.)',
                    initialValue: _controller.strengthUnit,
                    onChanged: _controller.setStrengthUnit,
                    validator: (v) => _controller.errorFor('strengthUnit'),
                    maxLength: 25,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _DropdownFormField<MedicineStatus>(
              label: 'Status',
              value: _controller.status,
              items: MedicineStatus.values
                  .map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase())))
                  .toList(),
              onChanged: (v) => _controller.setStatus(v!),
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
            _TextFormField(
              label: 'Notes',
              initialValue: _controller.notes,
              onChanged: _controller.setNotes,
              validator: (v) => _controller.errorFor('notes'),
              maxLines: 3,
              maxLength: 1000,
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
                  : Text(isEdit ? 'Save Changes' : 'Create Medicine'),
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
        ),
        child: Text(value == null ? 'Select date' : _formatDate(value!)),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}