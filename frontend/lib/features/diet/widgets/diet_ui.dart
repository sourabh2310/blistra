/// Small Diet-only helpers on top of the shared Blistra components: number
/// formatting, meal-type icons, and a glass text field for the cases
/// [GlassTextField] does not cover (length limits, submit on enter).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../models/meal.dart';
import '../models/meal_type.dart';

/// "320", "12.5".
String formatDietNumber(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);

/// "1,420" for headline calorie figures.
String formatKcal(double value) {
  final whole = value.round().toString();
  return whole.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
}

/// "750 ml", "1.8 L".
String formatWater(double milliliters) {
  if (milliliters >= 1000) {
    return '${(milliliters / 1000).toStringAsFixed(1)} L';
  }
  return '${milliliters.round()} ml';
}

/// Sum of the recorded calories of [meal]'s items, or null when no item has
/// a calorie value (missing data is never shown as zero).
double? mealCalories(Meal meal) {
  double? total;
  for (final item in meal.items) {
    final kcal = item.caloriesKcal;
    if (kcal != null) total = (total ?? 0) + kcal;
  }
  return total;
}

IconData mealTypeIcon(MealType type) => switch (type) {
      MealType.breakfast => Icons.wb_twilight_rounded,
      MealType.lunch => Icons.wb_sunny_outlined,
      MealType.snack => Icons.cookie_outlined,
      MealType.dinner => Icons.nightlight_outlined,
      MealType.other => Icons.restaurant_rounded,
    };

/// Glass text field matching [GlassTextField], with an optional hard length
/// limit (no visible counter) and a submit callback.
class DietTextField extends StatelessWidget {
  const DietTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? maxLength;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return FieldCard(
      label: label,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: 1,
        validator: validator,
        textInputAction: textInputAction,
        onFieldSubmitted: onSubmitted,
        autofocus: autofocus,
        inputFormatters: maxLength == null
            ? null
            : [LengthLimitingTextInputFormatter(maxLength)],
        style: TextStyle(fontSize: 14, color: colors.text),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: hint,
          contentPadding: EdgeInsets.zero,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Small uppercase caption used above form controls ("MEAL", "PREFERENCE").
class DietFormLabel extends StatelessWidget {
  const DietFormLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 0, 8),
      child: Text(text.toUpperCase(), style: BlistraText.caption(colors.muted)),
    );
  }
}
