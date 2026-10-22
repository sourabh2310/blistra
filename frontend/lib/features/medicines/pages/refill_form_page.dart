/// Create/edit refill record form page.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/page_header.dart';
import '../data/medicines_api_client.dart';
import '../models/refill.dart';
import '../state/refill_form_controller.dart';
import '../widgets/medicine_widgets.dart';

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
  MedicinesApiClient? _api;
  bool _saving = false;
  late final TextEditingController _quantity;
  late final TextEditingController _remaining;
  late final TextEditingController _notes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      final authState = context.read<AuthState>();
      _api = MedicinesApiClient(
        tokenProvider: () => authState.apiClient.token ?? '',
        onUnauthorized: authState.handleUnauthorized,
      );
      _controller = RefillFormController(
        _api!,
        medicineId: widget.medicineId,
        refill: widget.refill,
      );
      _quantity = TextEditingController(text: _controller.quantity);
      _remaining = TextEditingController(text: _controller.remainingQuantity);
      _notes = TextEditingController(text: _controller.notes);
    }
  }

  @override
  void dispose() {
    if (_api != null) {
      _quantity.dispose();
      _remaining.dispose();
      _notes.dispose();
    }
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.refill != null;
    final colors = BlistraColors.resolve(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: StickyActionBar(
        label: isEdit ? 'Save changes' : 'Record refill',
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
                eyebrow: isEdit ? 'Edit refill' : 'New refill',
                title: 'How much did you get?',
                showAvatar: false,
              ),
              const SizedBox(height: 10),
              PagePad(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DateFieldCard(
                      label: 'Refill date *',
                      value: _controller.refillDate,
                      lastDate: DateTime.now(),
                      error: _controller.errorFor('refillDate'),
                      onChanged: (d) =>
                          setState(() => _controller.setRefillDate(d)),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GlassTextField(
                            label: 'Quantity *',
                            controller: _quantity,
                            hint: '60',
                            onChanged: _controller.setQuantity,
                            validator: (v) => _controller.errorFor('quantity'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassTextField(
                            label: 'Remaining',
                            controller: _remaining,
                            hint: 'Optional',
                            onChanged: _controller.setRemainingQuantity,
                            validator: (v) =>
                                _controller.errorFor('remainingQuantity'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    GlassTextField(
                      label: 'Notes',
                      controller: _notes,
                      hint: 'Pharmacy, batch, price…',
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
