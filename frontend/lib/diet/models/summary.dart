import 'meal.dart';
import 'water.dart';
import 'wire.dart';
import 'nutrition_totals.dart';

/// The per-day food and nutrition picture (backend `DietSummaryResponse`).
class DietSummary {
  DietSummary({
    required this.date,
    required this.offsetMinutes,
    required this.mealCount,
    this.meals = const [],
    required this.waterCount,
    this.water = const [],
    this.waterTotalMilliliters,
    this.nutrition,
  });

  factory DietSummary.fromJson(Map<String, dynamic> json) {
    return DietSummary(
      date: DateTime.parse(json['date'] as String? ?? ''),
      offsetMinutes: (json['offsetMinutes'] as num?)?.toInt() ?? 0,
      mealCount: (json['mealCount'] as num?)?.toInt() ?? 0,
      meals: _list(json['meals'], Meal.fromJson),
      waterCount: (json['waterCount'] as num?)?.toInt() ?? 0,
      water: _list(json['water'], WaterRecord.fromJson),
      waterTotalMilliliters: toDouble(json['waterTotalMilliliters']),
      nutrition: json['nutrition'] is Map<String, dynamic>
          ? NutritionTotals.fromJson(json['nutrition'] as Map<String, dynamic>)
          : null,
    );
  }

  static List<T> _list<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
    if (json is! List) {
      return const [];
    }
    return json
        .whereType<Map<String, dynamic>>()
        .map(fromJson)
        .toList();
  }

  final DateTime date;
  final int offsetMinutes;
  final int mealCount;
  final List<Meal> meals;
  final int waterCount;
  final List<WaterRecord> water;
  final double? waterTotalMilliliters;
  final NutritionTotals? nutrition;
}