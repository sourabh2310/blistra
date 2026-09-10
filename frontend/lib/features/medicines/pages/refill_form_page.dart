/// Create/edit refill record form page.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/api/api_client.dart';
import '../data/medicines_api_client.dart'
import '../state/refill_form_controller.dart';

class RefillFormPage extends StatefulWidget {
  const RefillFormPage({
    super.key,
    required this.medicineId,
    this.refill,
  });

  final String medicineId;
  final Refill? refill;

  @override
  State<RefillFormPage> createState() => _RefillFormPageState();
}

class _RefillFormPageState extends State<RefillFormPage> {
  final _formKey = GlobalKey<FormState>();
  late RefillFormController _controller;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) {
      final apiClient = context.read<ApiClient>();
      final authState = context.read<AuthState>();
      _controller = RefillFormController(
        MedicinesApiClient(tokenProvider: () => authState.apiClient.token ?? ''),
        medicineId: widget.medicineId,
        refill: widget.refill,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.refill != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Refill' : 'Add Refill')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _DateFormField(
              label: 'Refill date *',
              value: _controller.refillDate,
              onChanged: _controller.setRefillDate,
              validator: (v) => _controller.errorFor('refillDate'),
            ),
            const SizedBox(height: 16),
            _TextFormField(
              label: 'Quantity *',
              initialValue: _controller.quantity,
              onChanged: _controller.setQuantity,
              validator: (v) => _controller.errorFor('quantity'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _TextFormField(
              label: 'Remaining quantity',
              initialValue: _controller.remainingQuantity,
              onChanged: _controller.setRemainingQuantity,
              validator: (v) => _controller.errorFor('remainingQuantity'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _TextFormField(
              label: 'Notes',
              initialValue: _controller.notes,
              onChanged: _controller.setNotes,
              validator: (v) => _controller.errorFor('notes'),
              maxLines: 3,
              maxLength: 500,
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
                  : Text(isEdit ? 'Save Changes' : 'Record Refill'),
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
          lastDate: DateTime.now(),
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