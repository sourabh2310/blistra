import 'wire.dart';

/// Sum of one nutrition component (backend `MacroTotalsResponse`).
class MacroTotals {
  MacroTotals({this.total, required this.recordedItems});

  factory MacroTotals.fromJson(Map<String, dynamic> json) {
    return MacroTotals(
      total: toDouble(json['total']),
      recordedItems: (json['recordedItems'] as num?)?.toInt() ?? 0,
    );
  }

  final double? total;
  final int recordedItems;

  bool get hasValue => total != null;
}

/// Aggregated nutrition for a day (backend `NutritionTotalsResponse`).
class NutritionTotals {
  NutritionTotals({
    this.caloriesKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
    this.fiberG,
  });

  factory NutritionTotals.fromJson(Map<String, dynamic> json) {
    return NutritionTotals(
      caloriesKcal: _macro(json['caloriesKcal']),
      proteinG: _macro(json['proteinG']),
      carbohydratesG: _macro(json['carbohydratesG']),
      fatG: _macro(json['fatG']),
      fiberG: _macro(json['fiberG']),
    );
  }

  static MacroTotals? _macro(dynamic json) {
    if (json is Map<String, dynamic>) {
      return MacroTotals.fromJson(json);
    }
    return null;
  }

  final MacroTotals? caloriesKcal;
  final MacroTotals? proteinG;
  final MacroTotals? carbohydratesG;
  final MacroTotals? fatG;
  final MacroTotals? fiberG;
}