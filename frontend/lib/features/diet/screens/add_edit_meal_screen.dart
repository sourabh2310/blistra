import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../models/item_draft.dart';
import '../models/meal.dart';
import '../models/meal_type.dart';
import '../validators.dart';
import '../widgets/diet_ui.dart';
import '../widgets/item_editor_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';

/// Creates a meal (with optional items) or edits meal-level fields.
class AddEditMealScreen extends StatefulWidget {
  const AddEditMealScreen({
    super.key,
    this.mealId,
    this.initial,
    this.initialType,
  });

  /// When non-null this screen edits that meal instead of creating one.
  final String? mealId;
  final Meal? initial;

  /// Preselected meal type for a new meal (e.g. from an empty Diet slot).
  final MealType? initialType;

  bool get isEdit => initial != null;

  @override
  State<AddEditMealScreen> createState() => _AddEditMealScreenState();
}

class _AddEditMealScreenState extends State<AddEditMealScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _notes;
  late MealType _mealType;
  late DateTime _consumedAt;
  final List<ItemDraft> _items = [];

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _title = TextEditingController(text: initial?.title ?? '');
    _notes = TextEditingController(text: initial?.notes ?? '');
    _mealType = initial?.mealType ?? widget.initialType ?? MealType.breakfast;
    _consumedAt = initial?.consumedAt ?? DateTime.now();
    if (initial != null) {
      _items.addAll(initial.items.map(ItemDraft.fromMealItem));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _consumedAt.isAfter(now) ? now : _consumedAt,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'When was this meal eaten?',
    );
    if (date == null || !mounted) {
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _consumedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (widget.isEdit) {
      setState(() => _saving = true);
      final controller = context.read<DietController>();
      final ok = await controller.updateMeal(
        id: widget.initial!.id,
        title: _title.text.trim(),
        mealType: _mealType.wireName,
        notes: _blankOrNull(_notes.text),
        consumedAt: _consumedAt,
      );
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        _showActionError(controller.lastActionError);
      }
      return;
    }

    setState(() => _saving = true);
    final controller = context.read<DietController>();
    final meal = await controller.createMeal(
      title: _title.text.trim(),
      mealType: _mealType.wireName,
      notes: _blankOrNull(_notes.text),
      consumedAt: _consumedAt,
      items: _items.map((draft) => draft.toMealItem()).toList(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (meal != null) {
      Navigator.of(context).pop(true);
    } else {
      _showActionError(controller.lastActionError);
    }
  }

  void _showActionError(String? error) {
    if (error == null || error.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  static String? _blankOrNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<void> _addOrEditItem({int? index}) async {
    final existing = index == null ? null : _items[index];
    final draft = await showModalBottomSheet<ItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (context) => ItemEditorSheet(initial: existing),
    );
    if (draft == null || !mounted) {
      return;
    }
    setState(() {
      if (index == null) {
        _items.add(draft);
      } else {
        _items[index] = draft;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            children: [
              BlistraPageHeader(
                eyebrow: widget.isEdit ? 'Edit meal' : 'New meal',
                title: widget.isEdit ? 'Edit this meal' : 'What did you eat?',
                showAvatar: false,
              ),
              PagePad(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DietTextField(
                      label: 'Meal title',
                      controller: _title,
                      hint: 'e.g. Avocado toast',
                      textInputAction: TextInputAction.next,
                      validator: Validators.mealTitle,
                    ),
                    const DietFormLabel('Meal'),
                  ],
                ),
                top: 10,
              ),
              ChipRow(
                labels: [for (final type in MealType.values) type.label],
                icons: [for (final type in MealType.values) mealTypeIcon(type)],
                selected: MealType.values.indexOf(_mealType),
                onSelected: (i) => setState(() => _mealType = MealType.values[i]),
              ),
              PagePad(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldCard(
                      label: 'Eaten at',
                      onTap: _pickDateTime,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              DateFormat('EEE, d MMM y · h:mm a').format(_consumedAt),
                            ),
                          ),
                          Icon(Icons.schedule_rounded, size: 18, color: colors.muted),
                        ],
                      ),
                    ),
                    DietTextField(
                      label: 'Notes',
                      controller: _notes,
                      hint: 'Optional',
                      maxLines: 3,
                      maxLength: 2000,
                      validator: (value) => Validators.notes(value),
                    ),
                  ],
                ),
                top: 12,
              ),
              if (!widget.isEdit) ...[
                const SizedBox(height: 14),
                SectionHeader(
                  title: 'Items',
                  actionLabel: 'Add item ›',
                  onAction: () => _addOrEditItem(),
                ),
                PagePad(
                  _items.isEmpty
                      ? EmptyCard(
                          message:
                              'No items yet. You can add a simple meal without items.',
                          action: 'Add item',
                          onAction: () => _addOrEditItem(),
                        )
                      : GlassList(
                          children: [
                            for (var i = 0; i < _items.length; i++)
                              GlassRow(
                                leading: const IconWell(Icons.restaurant_rounded),
                                title: _items[i].name,
                                subtitle: _items[i].summaryText,
                                onTap: () => _addOrEditItem(index: i),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Edit item',
                                      visualDensity: VisualDensity.compact,
                                      color: colors.muted,
                                      icon: const Icon(Icons.edit_outlined, size: 19),
                                      onPressed: () => _addOrEditItem(index: i),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove item',
                                      visualDensity: VisualDensity.compact,
                                      color: colors.muted,
                                      icon: const Icon(Icons.delete_outline, size: 19),
                                      onPressed: () =>
                                          setState(() => _items.removeAt(i)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        label: widget.isEdit ? 'Save changes' : 'Save meal',
        busy: _saving,
        onPressed: _save,
      ),
    );
  }
}
