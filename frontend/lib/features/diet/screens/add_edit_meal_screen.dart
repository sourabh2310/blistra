import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../models/item_draft.dart';
import '../models/meal.dart';
import '../models/meal_type.dart';
import '../validators.dart';
import '../widgets/item_editor_sheet.dart';

/// Creates a meal (with optional items) or edits meal-level fields.
class AddEditMealScreen extends StatefulWidget {
  const AddEditMealScreen({super.key, this.mealId, this.initial});

  /// When non-null this screen edits that meal instead of creating one.
  final String? mealId;
  final Meal? initial;

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
    _mealType = initial?.mealType ?? MealType.breakfast;
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Edit meal' : 'Add meal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            TextFormField(
              controller: _title,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Meal title',
                hintText: 'e.g. Avocado toast',
              ),
              validator: Validators.mealTitle,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in MealType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: _mealType == type,
                    onSelected: (_) => setState(() => _mealType = type),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Consumed at'),
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20, color: scheme.outline),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEE, MMM d, y • h:mm a').format(_consumedAt),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notes,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
                hintText: 'Optional',
              ),
              validator: (value) => Validators.notes(value),
            ),
            const SizedBox(height: 8),
            if (!widget.isEdit) ...[
              Row(
                children: [
                  Text('Items', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _addOrEditItem(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add item'),
                  ),
                ],
              ),
              if (_items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'No items yet. You can add a simple meal without items.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              for (var i = 0; i < _items.length; i++)
                Card(
                  child: ListTile(
                    title: Text(_items[i].name, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(_items[i].summaryText,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit item',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _addOrEditItem(index: i),
                        ),
                        IconButton(
                          tooltip: 'Remove item',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _items.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(widget.isEdit ? 'Save changes' : 'Save meal'),
          ),
        ),
      ),
    );
  }
}