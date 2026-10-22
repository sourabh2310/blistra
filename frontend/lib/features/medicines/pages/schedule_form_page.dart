/// Create/edit schedule form page.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/page_header.dart';
import '../data/medicines_api_client.dart';
import '../models/medicine_enums.dart';
import '../models/schedule.dart' show Schedule;
import '../state/schedule_form_controller.dart';
import '../util/insights.dart';
import '../widgets/medicine_widgets.dart';

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
  MedicinesApiClient? _api;
  bool _saving = false;
  late final TextEditingController _doseAmount;
  late final TextEditingController _doseUnit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_api == null) {
      final authState = context.read<AuthState>();
      _api = MedicinesApiClient(
        tokenProvider: () => authState.apiClient.token ?? '',
        onUnauthorized: authState.handleUnauthorized,
      );
      _controller = ScheduleFormController(
        _api!,
        medicineId: widget.medicineId,
        schedule: widget.schedule,
      );
      _doseAmount = TextEditingController(text: _controller.doseAmount);
      _doseUnit = TextEditingController(text: _controller.doseUnit);
    }
  }

  @override
  void dispose() {
    if (_api != null) {
      _doseAmount.dispose();
      _doseUnit.dispose();
    }
    _api?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.schedule != null;
    final colors = BlistraColors.resolve(context);
    final type = _controller.scheduleType;

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: StickyActionBar(
        label: isEdit ? 'Save changes' : 'Add schedule',
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
                eyebrow: isEdit ? 'Edit schedule' : 'New schedule',
                title: 'When do you take it?',
                showAvatar: false,
              ),
              const SizedBox(height: 10),
              PagePad(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FormLabel('Repeats *'),
                    GlassSegmented<ScheduleType>(
                      options: const [
                        (ScheduleType.daily, 'Daily'),
                        (ScheduleType.weekly, 'Weekly'),
                        (ScheduleType.customDays, 'Custom'),
                        (ScheduleType.asNeeded, 'As needed'),
                      ],
                      selected: type,
                      onChanged: (v) =>
                          setState(() => _controller.setScheduleType(v)),
                    ),
                    const SizedBox(height: 12),
                    if (type != ScheduleType.asNeeded)
                      _TimesField(
                        controller: _controller,
                        onChanged: () => setState(() {}),
                      ),
                    if (type == ScheduleType.weekly ||
                        type == ScheduleType.customDays)
                      _DaysField(
                        controller: _controller,
                        onChanged: () => setState(() {}),
                      ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: GlassTextField(
                            label: 'Dose amount',
                            controller: _doseAmount,
                            hint: '1',
                            onChanged: _controller.setDoseAmount,
                            validator: (v) => _controller.errorFor('doseAmount'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GlassTextField(
                            label: 'Unit',
                            controller: _doseUnit,
                            hint: 'tablet',
                            onChanged: _controller.setDoseUnit,
                            validator: (v) => _controller.errorFor('doseUnit'),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DateFieldCard(
                            label: 'Start date',
                            value: _controller.startDate,
                            onChanged: (d) =>
                                setState(() => _controller.setStartDate(d)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DateFieldCard(
                            label: 'End date',
                            value: _controller.endDate,
                            error: _controller.errorFor('endDate'),
                            onChanged: (d) =>
                                setState(() => _controller.setEndDate(d)),
                          ),
                        ),
                      ],
                    ),
                    FieldCard(
                      label: 'Active',
                      onTap: () => setState(
                        () => _controller.setActive(!_controller.active),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _controller.active
                                  ? "Counted in today's doses"
                                  : 'Paused, not counted today',
                              style: TextStyle(fontSize: 13, color: colors.muted),
                            ),
                          ),
                          Switch(
                            value: _controller.active,
                            onChanged: (v) =>
                                setState(() => _controller.setActive(v)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
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

class _TimesField extends StatelessWidget {
  const _TimesField({required this.controller, required this.onChanged});

  final ScheduleFormController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final error = controller.errorFor('times');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldCard(
          label: 'Times *',
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final t in controller.times)
                  _TimeChip(
                    label: timeLabel(t),
                    onRemove: () {
                      controller.setTimes(
                        controller.times.where((e) => e != t).toList(),
                      );
                      onChanged();
                    },
                  ),
                Pill('+ Add time', onTap: () => _pickTime(context)),
              ],
            ),
          ),
        ),
        if (controller.times.isEmpty && error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              error,
              style: TextStyle(color: colors.danger, fontSize: 11.5),
            ),
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
      onChanged();
    }
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(
        color: colors.inkAt(0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: colors.inkAt(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.text,
              fontFeatures: BlistraText.tabular,
            ),
          ),
          Semantics(
            button: true,
            label: 'Remove $label',
            child: InkResponse(
              onTap: onRemove,
              radius: 14,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close_rounded, size: 14, color: colors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaysField extends StatelessWidget {
  const _DaysField({required this.controller, required this.onChanged});

  final ScheduleFormController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final error = controller.errorFor('daysOfWeek');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldCard(
          label: 'Days *',
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (i) {
                final index = i + 1;
                final selected = controller.daysOfWeek.contains(index);
                return Semantics(
                  button: true,
                  selected: selected,
                  label: dayShort(index),
                  child: GestureDetector(
                    onTap: () {
                      final newList = List<int>.from(controller.daysOfWeek);
                      if (selected) {
                        newList.remove(index);
                      } else {
                        newList.add(index);
                      }
                      controller.setDaysOfWeek(newList);
                      onChanged();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? colors.accentText : colors.inkAt(0.06),
                        border: Border.all(
                          color: selected
                              ? colors.accentText
                              : colors.inkAt(0.14),
                        ),
                      ),
                      child: Text(
                        dayShort(index).substring(0, 2),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? colors.onAccent : colors.muted,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              error,
              style: TextStyle(color: colors.danger, fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}
