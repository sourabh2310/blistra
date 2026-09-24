/// Create / edit habit bottom sheet.
library;

import 'package:flutter/material.dart';

import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';

class HabitFormScreen extends StatefulWidget {
  const HabitFormScreen({super.key, this.existingHabit});

  final Habit? existingHabit;

  @override
  State<HabitFormScreen> createState() => _HabitFormScreenState();
}

class _HabitFormScreenState extends State<HabitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _targetUnitController = TextEditingController();
  final _targetMinutesController = TextEditingController();

  HabitType _type = HabitType.boolean;
  HabitStatus _status = HabitStatus.active;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingHabit != null) {
      final Habit habit = widget.existingHabit!;
      _nameController.text = habit.name;
      _descriptionController.text = habit.description ?? '';
      _type = habit.type;
      _status = habit.status;
      _targetValueController.text = habit.targetValue ?? '';
      _targetUnitController.text = habit.targetUnit ?? '';
      _targetMinutesController.text = habit.targetMinutes?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _targetUnitController.dispose();
    _targetMinutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.existingHabit != null;
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEdit ? 'Edit Habit' : 'Create Habit',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Drink water',
                ),
                validator: (String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  if (value.length > 100) {
                    return 'Name must be 100 characters or less';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Add details...',
                ),
                maxLines: 3,
                maxLength: 500,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<HabitType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: HabitType.values.map((HabitType t) {
                  return DropdownMenuItem(
                    value: t,
                    child: Text(t.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (HabitType? value) {
                  if (value != null) {
                    setState(() {
                      _type = value;
                      // Clear hidden type-specific fields so stale values are
                      // never sent (backend rejects inconsistent targets).
                      if (value != HabitType.count) {
                        _targetValueController.clear();
                        _targetUnitController.clear();
                      }
                      if (value != HabitType.duration) {
                        _targetMinutesController.clear();
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              if (_type == HabitType.count) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _targetValueController,
                        decoration: const InputDecoration(
                          labelText: 'Target Value *',
                          hintText: '8',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          if (_type != HabitType.count) return null;
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Target value is required';
                          final n = double.tryParse(t);
                          if (n == null || n <= 0) {
                            return 'Enter a number greater than 0';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _targetUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          hintText: 'glasses',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (_type == HabitType.duration) ...[
                TextFormField(
                  controller: _targetMinutesController,
                  decoration: const InputDecoration(
                    labelText: 'Target Minutes *',
                    hintText: '20',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (_type != HabitType.duration) return null;
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Target minutes is required';
                    final n = int.tryParse(t);
                    if (n == null || n <= 0) {
                      return 'Enter whole minutes greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],
              DropdownButtonFormField<HabitStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: HabitStatus.values.map((HabitStatus s) {
                  return DropdownMenuItem(
                    value: s,
                    child: Text(s.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (HabitStatus? value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEdit ? 'Save Changes' : 'Create Habit'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final HabitsController controller = HabitsScope.of(context);

    try {
      if (widget.existingHabit != null) {
        await controller.updateHabit(
          widget.existingHabit!.id,
          name: _nameController.text.trim(),
          type: _type,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          targetValue: _targetValueController.text.isEmpty
              ? null
              : _targetValueController.text,
          targetUnit: _targetUnitController.text.isEmpty
              ? null
              : _targetUnitController.text,
          targetMinutes: _targetMinutesController.text.isEmpty
              ? null
              : int.tryParse(_targetMinutesController.text),
          status: _status,
        );
      } else {
        await controller.createHabit(
          name: _nameController.text.trim(),
          type: _type,
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          targetValue: _targetValueController.text.isEmpty
              ? null
              : _targetValueController.text,
          targetUnit: _targetUnitController.text.isEmpty
              ? null
              : _targetUnitController.text,
          targetMinutes: _targetMinutesController.text.isEmpty
              ? null
              : int.tryParse(_targetMinutesController.text),
          status: _status,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingHabit != null
                ? 'Habit updated'
                : 'Habit created'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}