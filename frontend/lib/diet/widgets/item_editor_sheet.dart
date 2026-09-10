import 'package:flutter/material.dart';

import '../models/item_draft.dart';
import '../validators.dart';

/// Modal bottom sheet (via `showModalBottomSheet<ItemDraft>`) for entering or
/// editing a single meal item. Returns the drafted item on save.
class ItemEditorSheet extends StatefulWidget {
  const ItemEditorSheet({super.key, this.initial});

  final ItemDraft? initial;

  @override
  State<ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<ItemEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _quantity;
  late final TextEditingController _unit;
  late final TextEditingController _caloriesKcal;
  late final TextEditingController _proteinG;
  late final TextEditingController _carbohydratesG;
  late final TextEditingController _fatG;
  late final TextEditingController _fiberG;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _quantity = TextEditingController(text: _optional(initial?.quantity));
    _unit = TextEditingController(text: initial?.unit ?? '');
    _caloriesKcal = TextEditingController(text: _optional(initial?.caloriesKcal));
    _proteinG = TextEditingController(text: _optional(initial?.proteinG));
    _carbohydratesG = TextEditingController(text: _optional(initial?.carbohydratesG));
    _fatG = TextEditingController(text: _optional(initial?.fatG));
    _fiberG = TextEditingController(text: _optional(initial?.fiberG));
    _notes = TextEditingController(text: initial?.notes ?? '');
  }

  static String _optional(double? value) => value == null
      ? ''
      : (value == value.roundToDouble()
          ? value.toInt().toString()
          : value.toStringAsFixed(3));

  @override
  void dispose() {
    for (final controller in [
      _name, _quantity, _unit, _caloriesKcal, _proteinG,
      _carbohydratesG, _fatG, _fiberG, _notes,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final draft = ItemDraft(
      name: _name.text.trim(),
      quantity: Validators.parseOptionalNumber(_quantity.text),
      unit: _blank(_unit.text),
      caloriesKcal: Validators.parseOptionalNumber(_caloriesKcal.text),
      proteinG: Validators.parseOptionalNumber(_proteinG.text),
      carbohydratesG: Validators.parseOptionalNumber(_carbohydratesG.text),
      fatG: Validators.parseOptionalNumber(_fatG.text),
      fiberG: Validators.parseOptionalNumber(_fiberG.text),
      notes: _blank(_notes.text),
    );
    Navigator.of(context).pop(draft);
  }

  static String? _blank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Item', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Food name'),
                validator: Validators.itemName,
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantity'),
                      validator: Validators.positiveNumber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _unit,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Unit'),
                      validator: Validators.unit,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Nutrition (optional)', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              TextFormField(
                controller: _caloriesKcal,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Calories (kcal)'),
                validator: Validators.nonNegativeNumber,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _proteinG,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Protein (g)'),
                      validator: Validators.nonNegativeNumber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _carbohydratesG,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Carbs (g)'),
                      validator: Validators.nonNegativeNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fatG,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Fat (g)'),
                      validator: Validators.nonNegativeNumber,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _fiberG,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Fiber (g)'),
                      validator: Validators.nonNegativeNumber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
                validator: (value) => Validators.notes(value, max: 1000),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _submit,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}