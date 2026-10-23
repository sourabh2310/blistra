/// Create / edit habit bottom sheet.
library;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../habit_insights.dart';
import '../habits_controller.dart';
import '../habits_scope.dart';
import '../models.dart';

/// Opens the habit form as a bottom sheet; edits [existingHabit] when set.
Future<void> showHabitFormSheet(BuildContext context, {Habit? existingHabit}) {
  // The sheet is built under the root navigator, above the page's HabitsScope,
  // so hand the controller to it explicitly.
  final HabitsController controller = HabitsScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => HabitsScope(
      controller: controller,
      child: HabitFormScreen(existingHabit: existingHabit),
    ),
  );
}

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
  HabitFrequency _frequency = HabitFrequency.daily;
  final Set<String> _daysOfWeek = {
    'MONDAY',
    'TUESDAY',
    'WEDNESDAY',
    'THURSDAY',
    'FRIDAY',
    'SATURDAY',
    'SUNDAY',
  };
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
    final colors = BlistraColors.resolve(context);

    final Widget fields = Padding(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 12, kPageGutter, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: colors.inkAt(0.25),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isEdit ? 'EDIT HABIT' : 'NEW HABIT',
            style: BlistraText.eyebrow(colors.accentText),
          ),
          const SizedBox(height: 6),
          Text(
            isEdit ? 'Fine-tune this habit' : 'What do you want to build?',
            style: BlistraText.serif(26, colors.text, height: 1.1),
          ),
          const SizedBox(height: 16),
          GlassTextField(
            label: 'Name',
            controller: _nameController,
            hint: 'e.g. Drink water',
            textInputAction: TextInputAction.next,
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
          FieldCard(
            label: 'Description (optional)',
            child: TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              minLines: 1,
              maxLength: 500,
              style: TextStyle(fontSize: 14, color: colors.text),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: 'Add details...',
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                counterStyle: TextStyle(fontSize: 10, color: colors.muted),
              ),
            ),
          ),
          if (!isEdit) ...[
            _Label('Schedule'),
            GlassSegmented<HabitFrequency>(
              options: const [
                (HabitFrequency.daily, 'Daily'),
                (HabitFrequency.weekly, 'Weekly'),
              ],
              selected: _frequency,
              onChanged: (value) => setState(() => _frequency = value),
            ),
            if (_frequency == HabitFrequency.weekly) ...[
              const SizedBox(height: 10),
              _DayToggles(
                selected: _daysOfWeek,
                onChanged: (day, on) => setState(() {
                  if (on) {
                    _daysOfWeek.add(day);
                  } else {
                    _daysOfWeek.remove(day);
                  }
                }),
              ),
              if (_daysOfWeek.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Choose at least one day',
                    style: TextStyle(fontSize: 12, color: colors.danger),
                  ),
                ),
            ],
            const SizedBox(height: 12),
          ],
          _Label('Type'),
          GlassSegmented<HabitType>(
            options: [
              for (final HabitType t in HabitType.values) (t, habitTypeLabel(t)),
            ],
            selected: _type,
            onChanged: (HabitType value) {
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
            },
          ),
          const SizedBox(height: 12),
          if (_type == HabitType.count)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GlassTextField(
                    label: 'Target value *',
                    controller: _targetValueController,
                    hint: '8',
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
                const SizedBox(width: 10),
                Expanded(
                  child: GlassTextField(
                    label: 'Unit',
                    controller: _targetUnitController,
                    hint: 'glasses',
                  ),
                ),
              ],
            ),
          if (_type == HabitType.duration)
            GlassTextField(
              label: 'Target minutes *',
              controller: _targetMinutesController,
              hint: '20',
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
          _Label('Status'),
          GlassSegmented<HabitStatus>(
            options: [
              for (final HabitStatus s in HabitStatus.values)
                (s, habitStatusLabel(s)),
            ],
            selected: _status,
            onChanged: (HabitStatus value) => setState(() => _status = value),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );

    final Widget saveBar = _SaveBar(
      label: isEdit ? 'Save changes' : 'Create habit',
      busy: _submitting,
      onPressed: _submit,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            // In a height-bounded sheet the fields scroll above a pinned Save;
            // inside a parent scroll view (Quick add) Save follows the fields.
            if (!constraints.maxHeight.isFinite) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [fields, saveBar],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(child: SingleChildScrollView(child: fields)),
                saveBar,
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.existingHabit == null &&
        _frequency == HabitFrequency.weekly &&
        _daysOfWeek.isEmpty) {
      setState(() {});
      return;
    }

    setState(() => _submitting = true);

    try {
      final HabitsController controller = HabitsScope.of(context);
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
        final created = await controller.createHabit(
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
        await controller.upsertSchedule(
          created.id,
          frequency: _frequency,
          daysOfWeek: _frequency == HabitFrequency.weekly
              ? _daysOfWeek.toList()
              : null,
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

/// Small caps label above a non-text control.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 0, 8),
      child: Text(text.toUpperCase(), style: BlistraText.caption(colors.muted)),
    );
  }
}

/// Seven round day toggles for a weekly schedule.
class _DayToggles extends StatelessWidget {
  const _DayToggles({required this.selected, required this.onChanged});

  final Set<String> selected;
  final void Function(String day, bool on) onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final String day in kHabitWeekdays)
          Semantics(
            button: true,
            selected: selected.contains(day),
            label: day[0] + day.substring(1).toLowerCase(),
            child: GestureDetector(
              onTap: () => onChanged(day, !selected.contains(day)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected.contains(day)
                      ? colors.accentText
                      : colors.glassFill,
                  border: Border.all(
                    color: selected.contains(day)
                        ? colors.accentText
                        : colors.glassBorder,
                  ),
                ),
                child: Text(
                  day[0] + day.substring(1, 2).toLowerCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected.contains(day)
                        ? colors.onAccent
                        : colors.muted,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Save pinned under the scrolling fields. Like [StickyActionBar], but it
/// fades into the sheet colour instead of the page background.
class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.sheet.withValues(alpha: 0), colors.sheet],
          stops: const [0, 0.35],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kPageGutter, 14, kPageGutter, 14),
          child: FilledButton(
            onPressed: busy ? null : onPressed,
            child: busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.onAccent,
                    ),
                  )
                : Text(label),
          ),
        ),
      ),
    );
  }
}
