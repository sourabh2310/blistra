import 'meal.dart';

/// An item being composed in the UI before it is sent to the backend.
class ItemDraft {
  ItemDraft({
    this.name = '',
    this.quantity,
    this.unit,
    this.caloriesKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
    this.fiberG,
    this.notes,
  });

  final String name;
  final double? quantity;
  final String? unit;
  final double? caloriesKcal;
  final double? proteinG;
  final double? carbohydratesG;
  final double? fatG;
  final double? fiberG;
  final String? notes;

  MealItem toMealItem() => MealItem(
        name: name,
        quantity: quantity,
        unit: unit,
        caloriesKcal: caloriesKcal,
        proteinG: proteinG,
        carbohydratesG: carbohydratesG,
        fatG: fatG,
        fiberG: fiberG,
        notes: notes,
      );

  static ItemDraft fromMealItem(MealItem item) => ItemDraft(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        caloriesKcal: item.caloriesKcal,
        proteinG: item.proteinG,
        carbohydratesG: item.carbohydratesG,
        fatG: item.fatG,
        fiberG: item.fiberG,
        notes: item.notes,
      );

  String get summaryText {
    final parts = <String>[];
    if (quantity != null) {
      parts.add(_fmt(quantity!));
      if (unit != null && unit!.isNotEmpty) {
        parts.add(unit!);
      }
    }
    if (caloriesKcal != null) {
      parts.add('${_fmt(caloriesKcal!)} kcal');
    }
    if (parts.isEmpty) {
      return 'No details';
    }
    return parts.join(', ');
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}