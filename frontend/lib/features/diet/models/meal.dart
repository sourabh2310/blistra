import 'meal_type.dart';
import 'wire.dart';

/// A single food item inside a meal (backend `MealItemResponse`).
class MealItem {
  MealItem({
    this.id,
    required this.name,
    this.quantity,
    this.unit,
    this.caloriesKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
    this.fiberG,
    this.notes,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      id: json['id'] as String?,
      name: json['name'] as String? ?? '',
      quantity: toDouble(json['quantity']),
      unit: json['unit'] as String?,
      caloriesKcal: toDouble(json['caloriesKcal']),
      proteinG: toDouble(json['proteinG']),
      carbohydratesG: toDouble(json['carbohydratesG']),
      fatG: toDouble(json['fatG']),
      fiberG: toDouble(json['fiberG']),
      notes: json['notes'] as String?,
    );
  }

  /// Constructs the payload for `POST /api/v1/diet/meals/{id}/items` and
  /// `PUT .../items/{itemId}` (backend `CreateMealItemRequest`).
  Map<String, dynamic> toItemRequest() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'caloriesKcal': caloriesKcal,
      'proteinG': proteinG,
      'carbohydratesG': carbohydratesG,
      'fatG': fatG,
      'fiberG': fiberG,
      'notes': notes,
    };
  }

  final String? id;
  final String name;
  final double? quantity;
  final String? unit;
  final double? caloriesKcal;
  final double? proteinG;
  final double? carbohydratesG;
  final double? fatG;
  final double? fiberG;
  final String? notes;

  bool get hasNutrition =>
      caloriesKcal != null ||
      proteinG != null ||
      carbohydratesG != null ||
      fatG != null ||
      fiberG != null;
}

/// A single meal including its items (backend `MealResponse`).
class Meal {
  Meal({
    required this.id,
    required this.mealType,
    required this.title,
    this.notes,
    required this.consumedAt,
    required this.createdAt,
    this.updatedAt,
    this.items = const [],
  });

  factory Meal.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    return Meal(
      id: json['id'] as String? ?? '',
      mealType: MealType.fromWire(json['mealType'] as String?),
      title: json['title'] as String? ?? '',
      notes: json['notes'] as String?,
      consumedAt: DateTime.parse(json['consumedAt'] as String? ?? '')
          .toLocal(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      items: items is List
          ? items
              .whereType<Map<String, dynamic>>()
              .map(MealItem.fromJson)
              .toList()
          : const [],
    );
  }

  final String id;
  final MealType mealType;
  final String title;
  final String? notes;
  final DateTime consumedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<MealItem> items;

  MealItem? itemById(String itemId) {
    for (final item in items) {
      if (item.id == itemId) {
        return item;
      }
    }
    return null;
  }
}

/// A meal without its items, as returned by the paginated list endpoint
/// (backend `MealSummaryResponse`).
class MealSummary {
  MealSummary({
    required this.id,
    required this.mealType,
    required this.title,
    required this.consumedAt,
    this.createdAt,
    this.updatedAt,
    required this.itemCount,
  });

  factory MealSummary.fromJson(Map<String, dynamic> json) {
    return MealSummary(
      id: json['id'] as String? ?? '',
      mealType: MealType.fromWire(json['mealType'] as String?),
      title: json['title'] as String? ?? '',
      consumedAt: DateTime.parse(json['consumedAt'] as String? ?? '')
          .toLocal(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final MealType mealType;
  final String title;
  final DateTime consumedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int itemCount;
}