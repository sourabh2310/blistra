/// Create/edit medicine form page.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/page_header.dart';
import '../data/medicines_api_client.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../state/medicine_form_controller.dart';
import '../widgets/medicine_widgets.dart';

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

  bool _initialized = false;

  late final TextEditingController _name;
  late final TextEditingController _genericName;
  late final TextEditingController _form;
  late final TextEditingController _strength;
  late final TextEditingController _strengthUnit;
  late final TextEditingController _notes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final authState = context.read<AuthState>();
      final api = MedicinesApiClient(
        tokenProvider: () => authState.apiClient.token ?? '',
        onUnauthorized: () => authState.handleUnauthorized(),
      );
      _controller =
          MedicineFormController(api, medicine: widget.medicine);
      _name = TextEditingController(text: _controller.name);
      _genericName = TextEditingController(text: _controller.genericName);
      _form = TextEditingController(text: _controller.form);
      _strength = TextEditingController(text: _controller.strength);
      _strengthUnit = TextEditingController(text: _controller.strengthUnit);
      _notes = TextEditingController(text: _controller.notes);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    if (_initialized) {
      for (final c in [_name, _genericName, _form, _strength, _strengthUnit, _notes]) {
        c.dispose();
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.medicine != null;
    final colors = BlistraColors.resolve(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: StickyActionBar(
        label: isEdit ? 'Save changes' : 'Add medicine',
        busy: _saving,
        onPressed: _save,
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              BlistraPageHeader(
                eyebrow: isEdit ? 'Edit medicine' : 'New medicine',
                title: isEdit ? 'Update the details' : 'What are you taking?',
                showAvatar: false,
              ),
              const SizedBox(height: 10),
              PagePad(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlassTextField(
                      label: 'Name *',
                      controller: _name,
                      hint: 'e.g. Metformin',
                      onChanged: _controller.setName,
                      validator: (v) => _controller.errorFor('name'),
                      textInputAction: TextInputAction.next,
                    ),
                    GlassTextField(
                      label: 'Generic name',
                      controller: _genericName,
                      onChanged: _controller.setGenericName,
                      validator: (v) => _controller.errorFor('genericName'),
                      textInputAction: TextInputAction.next,
                    ),
                    GlassTextField(
                      label: 'Form',
                      controller: _form,
                      hint: 'Tablet, capsule, syrup…',
                      onChanged: _controller.setForm,
                      validator: (v) => _controller.errorFor('form'),
                      textInputAction: TextInputAction.next,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GlassTextField(
                            label: 'Strength',
                            controller: _strength,
                            hint: '500',
                            onChanged: _controller.setStrength,
                            validator: (v) => _controller.errorFor('strength'),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassTextField(
                            label: 'Unit',
                            controller: _strengthUnit,
                            hint: 'mg, ml…',
                            onChanged: _controller.setStrengthUnit,
                            validator: (v) => _controller.errorFor('strengthUnit'),
                          ),
                        ),
                      ],
                    ),
                    const FormLabel('Status'),
                    GlassSegmented<MedicineStatus>(
                      options: const [
                        (MedicineStatus.active, 'Active'),
                        (MedicineStatus.paused, 'Paused'),
                        (MedicineStatus.completed, 'Completed'),
                        (MedicineStatus.archived, 'Archived'),
                      ],
                      selected: _controller.status,
                      onChanged: (v) => setState(() => _controller.setStatus(v)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DateFieldCard(
                            label: 'Start date',
                            value: _controller.startDate,
                            onChanged: (d) => setState(() => _controller.setStartDate(d)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DateFieldCard(
                            label: 'End date',
                            value: _controller.endDate,
                            error: _controller.errorFor('endDate'),
                            onChanged: (d) => setState(() => _controller.setEndDate(d)),
                          ),
                        ),
                      ],
                    ),
                    GlassTextField(
                      label: 'Notes',
                      controller: _notes,
                      hint: 'Take after meals…',
                      onChanged: _controller.setNotes,
                      validator: (v) => _controller.errorFor('notes'),
                      maxLines: 3,
                    ),
                    if (_controller.hasErrors)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                        child: Text(
                          'Please fix the highlighted fields',
                          style: TextStyle(color: colors.danger, fontSize: 12.5),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_controller.validate()) {
      setState(() {});
      _formKey.currentState!.validate();
      return;
    }
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
