import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/diet/diet_api.dart';
import 'package:frontend/features/diet/diet_controller.dart';
import 'package:frontend/features/diet/diet_trends.dart';
import 'package:frontend/features/diet/models/diet_profile.dart';
import 'package:frontend/features/diet/models/meal.dart';
import 'package:frontend/features/diet/models/meal_type.dart';
import 'package:frontend/features/diet/models/nutrition_totals.dart';
import 'package:frontend/features/diet/models/paged.dart';
import 'package:frontend/features/diet/models/summary.dart';
import 'package:frontend/features/diet/models/water.dart';
import 'package:frontend/features/diet/validators.dart';

DietSummary _day(
  DateTime date, {
  double? calories,
  double? protein,
  double? waterMl,
}) =>
    DietSummary(
      date: date,
      offsetMinutes: 330,
      mealCount: calories == null ? 0 : 1,
      waterCount: waterMl == null ? 0 : 1,
      waterTotalMilliliters: waterMl,
      nutrition: calories == null && protein == null
          ? null
          : NutritionTotals(
              caloriesKcal: calories == null
                  ? null
                  : MacroTotals(total: calories, recordedItems: 1),
              proteinG: protein == null
                  ? null
                  : MacroTotals(total: protein, recordedItems: 1),
            ),
    );

class _FakeDietApi implements DietApi {
  int mutated = 0;
  int summaryCalls = 0;
  bool failNext = false;

  @override
  Future<DietProfile> getProfile() =>
      throw UnimplementedError();

  @override
  Future<DietProfile> upsertProfile(DietProfile profile) =>
      throw UnimplementedError();

  @override
  Future<Meal> createMeal({
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
    required List<MealItem> items,
  }) async {
    if (failNext) {
      throw Exception('nope');
    }
    mutated++;
    return Meal(
      id: 'meal-1',
      mealType: MealType.breakfast,
      title: title,
      consumedAt: consumedAt,
      createdAt: consumedAt,
      items: items,
    );
  }

  @override
  Future<Meal> updateMeal(
    String id, {
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<Meal> getMeal(String id) => throw UnimplementedError();

  @override
  Future<PageResult<MealSummary>> listMeals({
    DateTime? date,
    int offsetMinutes = 0,
    int page = 0,
    int size = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMeal(String id) async {
    if (failNext) {
      throw Exception('nope');
    }
    mutated++;
  }

  @override
  Future<MealItem> addMealItem(String mealId, MealItem item) =>
      throw UnimplementedError();

  @override
  Future<MealItem> updateMealItem(
          String mealId, String itemId, MealItem item) =>
      throw UnimplementedError();

  @override
  Future<void> deleteMealItem(String mealId, String itemId) =>
      throw UnimplementedError();

  @override
  Future<PageResult<WaterRecord>> listWater({
    DateTime? date,
    int offsetMinutes = 0,
    int page = 0,
    int size = 20,
  }) =>
      throw UnimplementedError();

  @override
  Future<WaterRecord> createWater({
    required double amount,
    required String unit,
    required DateTime consumedAt,
  }) async {
    mutated++;
    return WaterRecord(
      id: 'water-1',
      amount: amount,
      unit: WaterUnit.fromWire(unit),
      consumedAt: consumedAt,
    );
  }

  @override
  Future<WaterRecord> updateWater(
    String id, {
    required double amount,
    required String unit,
    required DateTime consumedAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deleteWater(String id) => throw UnimplementedError();

  @override
  Future<DietSummary> dailySummary(DateTime date,
      {int offsetMinutes = 0}) async {
    summaryCalls++;
    return _day(date);
  }
}

void main() {
  group('TrendsSummary', () {
    test('averages exclude days without recorded values', () {
      final days = [
        _day(DateTime(2026, 9, 22), calories: 1500, protein: 60),
        _day(DateTime(2026, 9, 23)),
        _day(DateTime(2026, 9, 24), calories: 2100, protein: 80),
      ];
      final trends = summarizeTrends(days);
      // (1500 + 2100) / 2 — the empty day is not treated as zero.
      expect(trends.averageCaloriesKcal, 1800);
      expect(trends.averageProteinG, 70);
      expect(trends.daysWithMeals, 2);
    });

    test('no data yields null averages, not fake zeros', () {
      final trends = summarizeTrends([
        _day(DateTime(2026, 9, 24)),
        _day(DateTime(2026, 9, 23)),
      ]);
      expect(trends.averageCaloriesKcal, isNull);
      expect(trends.averageProteinG, isNull);
      expect(trends.averageWaterMilliliters, isNull);
      expect(trends.daysWithMeals, 0);
    });

    test('days are ordered oldest first regardless of input order', () {
      final trends = summarizeTrends([
        _day(DateTime(2026, 9, 24), calories: 2000),
        _day(DateTime(2026, 9, 22), calories: 1000),
      ]);
      expect(trends.days.first.date.day, 22);
      expect(trends.days.last.date.day, 24);
      expect(trends.averageCaloriesKcal, 1500);
    });

    test('water average covers only recorded days', () {
      final trends = summarizeTrends([
        _day(DateTime(2026, 9, 24), waterMl: 1400),
        _day(DateTime(2026, 9, 23), waterMl: 600),
        _day(DateTime(2026, 9, 22)),
      ]);
      expect(trends.averageWaterMilliliters, 1000);
    });

    test('empty input yields empty trends', () {
      final trends = summarizeTrends(const []);
      expect(trends.isEmpty, isTrue);
      expect(trends.averageCaloriesKcal, isNull);
    });
  });

  group('Diet models preserve missing nutrition', () {
    test('MacroTotals without total has no value', () {
      final macro = MacroTotals.fromJson({'total': null, 'recordedItems': 0});
      expect(macro.total, isNull);
      expect(macro.hasValue, isFalse);
    });

    test('MealItem keeps null macros (not zero)', () {
      final item = MealItem.fromJson({'name': 'Water'});
      expect(item.caloriesKcal, isNull);
      expect(item.proteinG, isNull);
      expect(item.hasNutrition, isFalse);
    });

    test('WaterRecord glasses do not convert to millilitres', () {
      final glass = WaterRecord(
        id: 'w',
        amount: 2,
        unit: WaterUnit.glass,
        consumedAt: DateTime(2026, 9, 24),
      );
      expect(glass.milliliters, 0);
      final ml = WaterRecord(
        id: 'w2',
        amount: 250,
        unit: WaterUnit.ml,
        consumedAt: DateTime(2026, 9, 24),
      );
      expect(ml.milliliters, 250);
    });
  });

  group('Validators', () {
    test('water amount requires a positive number', () {
      expect(Validators.waterAmount(''), isNotNull);
      expect(Validators.waterAmount('0'), isNotNull);
      expect(Validators.waterAmount('-5'), isNotNull);
      expect(Validators.waterAmount('abc'), isNotNull);
      expect(Validators.waterAmount('250'), isNull);
    });

    test('meal title is required', () {
      expect(Validators.mealTitle('  '), isNotNull);
      expect(Validators.mealTitle('Breakfast'), isNull);
    });

    test('nutrition allows zero but not negatives', () {
      expect(Validators.nonNegativeNumber('0'), isNull);
      expect(Validators.nonNegativeNumber('-1'), isNotNull);
      expect(Validators.nonNegativeNumber(''), isNull);
    });
  });

  group('DietController mutations', () {
    test('createMeal reloads summary and notifies', () async {
      final api = _FakeDietApi();
      int notified = 0;
      final controller = DietController(api,
          onMutated: () async {
            notified++;
          });
      final meal = await controller.createMeal(
        title: 'Oats',
        mealType: 'BREAKFAST',
        consumedAt: DateTime(2026, 9, 24, 8),
        items: [MealItem(name: 'Oats', caloriesKcal: 320)],
      );
      expect(meal, isNotNull);
      expect(meal!.title, 'Oats');
      expect(api.summaryCalls, 1);
      expect(notified, 1);
      controller.dispose();
    });

    test('failed delete keeps error and skips notify', () async {
      final api = _FakeDietApi()..failNext = true;
      int notified = 0;
      final controller = DietController(api,
          onMutated: () async {
            notified++;
          });
      expect(await controller.deleteMeal('meal-1'), isFalse);
      expect(controller.lastActionError, isNotNull);
      expect(notified, 0);
      controller.dispose();
    });

    test('future water time is rejected client-side', () async {
      final api = _FakeDietApi();
      final controller = DietController(api);
      expect(
          await controller.addWater(
            amount: 250,
            unit: 'ml',
            consumedAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          isFalse);
      expect(api.mutated, 0);
      controller.dispose();
    });

    test('loadRangeSummaries fetches a bounded window', () async {
      final api = _FakeDietApi();
      final controller = DietController(api);
      final days = await controller.loadRangeSummaries(days: 7);
      expect(days.length, 7);
      expect(api.summaryCalls, 7);
      controller.dispose();
    });
  });
}
