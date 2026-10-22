import 'package:flutter/material.dart';

import '../models/item_draft.dart';
import '../validators.dart';
import 'diet_ui.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';

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

  Widget _number(String label, TextEditingController controller,
          FormFieldValidator<String> validator) =>
      DietTextField(
        label: label,
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        validator: validator,
      );

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 10),
            Expanded(child: b),
          ],
        );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(kPageGutter, 18, kPageGutter, 12),
                child: Text(
                  widget.initial == null ? 'Add item' : 'Edit item',
                  style: BlistraText.serif(22, colors.text),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DietTextField(
                        label: 'Food name',
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        validator: Validators.itemName,
                      ),
                      pair(
                        _number('Quantity', _quantity, Validators.positiveNumber),
                        DietTextField(
                          label: 'Unit',
                          controller: _unit,
                          hint: 'g, cup, slice',
                          textInputAction: TextInputAction.next,
                          validator: Validators.unit,
                        ),
                      ),
                      const DietFormLabel('Nutrition (optional)'),
                      _number('Calories (kcal)', _caloriesKcal,
                          Validators.nonNegativeNumber),
                      pair(
                        _number('Protein (g)', _proteinG,
                            Validators.nonNegativeNumber),
                        _number('Carbs (g)', _carbohydratesG,
                            Validators.nonNegativeNumber),
                      ),
                      pair(
                        _number('Fat (g)', _fatG, Validators.nonNegativeNumber),
                        _number('Fiber (g)', _fiberG,
                            Validators.nonNegativeNumber),
                      ),
                      DietTextField(
                        label: 'Notes',
                        controller: _notes,
                        maxLines: 2,
                        maxLength: 1000,
                        validator: (value) => Validators.notes(value, max: 1000),
                      ),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(kPageGutter, 8, kPageGutter, 14),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: _submit,
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
