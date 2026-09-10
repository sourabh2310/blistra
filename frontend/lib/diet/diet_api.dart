import '../core/api_client.dart';
import 'models/diet_profile.dart';
import 'models/meal.dart';
import 'models/paged.dart';
import 'models/summary.dart';
import 'models/water.dart';
import 'models/wire.dart';

String _dateParam(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Abstraction over the Diet backend so UI controllers can be tested against
/// an in-memory fake.
abstract class DietApi {
  Future<DietProfile> getProfile();

  Future<DietProfile> upsertProfile(DietProfile profile);

  Future<Meal> createMeal({
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
    required List<MealItem> items,
  });

  Future<Meal> updateMeal(
    String id, {
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
  });

  Future<Meal> getMeal(String id);

  Future<PageResult<MealSummary>> listMeals({
    DateTime? date,
    int offsetMinutes = 0,
    int page = 0,
    int size = 20,
  });

  Future<void> deleteMeal(String id);

  Future<MealItem> addMealItem(String mealId, MealItem item);

  Future<MealItem> updateMealItem(String mealId, String itemId, MealItem item);

  Future<void> deleteMealItem(String mealId, String itemId);

  Future<PageResult<WaterRecord>> listWater({
    DateTime? date,
    int offsetMinutes = 0,
    int page = 0,
    int size = 20,
  });

  Future<WaterRecord> createWater({
    required double amount,
    required String unit,
    required DateTime consumedAt,
  });

  Future<WaterRecord> updateWater(
    String id, {
    required double amount,
    required String unit,
    required DateTime consumedAt,
  });

  Future<void> deleteWater(String id);

  Future<DietSummary> dailySummary(DateTime date, {int offsetMinutes = 0});
}

/// Production [DietApi] backed by the real `/api/v1/diet` endpoints.
class HttpDietApi implements DietApi {
  HttpDietApi(this._client);

  final ApiClient _client;

  @override
  Future<DietProfile> getProfile() async {
    final json = await _client.getJson('/api/v1/diet/profile');
    return DietProfile.fromJson(_map(json));
  }

  @override
  Future<DietProfile> upsertProfile(DietProfile profile) async {
    final json = await _client.putJson('/api/v1/diet/profile', body: profile.toRequest());
    return DietProfile.fromJson(_map(json));
  }

  @override
  Future<Meal> createMeal({
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
    required List<MealItem> items,
  }) async {
    final json = await _client.postJson('/api/v1/diet/meals', body: {
      'title': title,
      'mealType': mealType,
      'notes': notes,
      'consumedAt': isoWithOffset(consumedAt),
      'items': items.map((item) => item.toItemRequest()).toList(),
    });
    return Meal.fromJson(_map(json));
  }

  @override
  Future<Meal> updateMeal(
    String id, {
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
  }) async {
    final json = await _client.putJson('/api/v1/diet/meals/$id', body: {
      'title': title,
      'mealType': mealType,
      'notes': notes,
      'consumedAt': isoWithOffset(consumedAt),
    });
    return Meal.fromJson(_map(json));
  }

  @override
  Future<Meal> getMeal(String id) async {
    final json = await _client.getJson('/api/v1/diet/meals/$id');
    return Meal.fromJson(_map(json));
  }

  @override
  Future<PageResult<MealSummary>> listMeals({
    DateTime? date,
    int offsetMinutes = 0,
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, String>{
      'offsetMinutes': '$offsetMinutes',
      'page': '$page',
      'size': '$size',
      if (date != null) 'date': _dateParam(date),
    };
    final json = await _client.getJson('/api/v1/diet/meals', query: query);
    return PageResult.fromJson(_map(json), MealSummary.fromJson);
  }

  @override
  Future<void> deleteMeal(String id) async {
    await _client.deleteJson('/api/v1/diet/meals/$id');
  }

  @override
  Future<MealItem> addMealItem(String mealId, MealItem item) async {
    final json = await _client.postJson(
      '/api/v1/diet/meals/$mealId/items',
      body: item.toItemRequest(),
    );
    return MealItem.fromJson(_map(json));
  }

  @override
  Future<MealItem> updateMealItem(
      String mealId, String itemId, MealItem item) async {
    final json = await _client.putJson(
      '/api/v1/diet/meals/$mealId/items/$itemId',
      body: item.toItemRequest(),
    );
    return MealItem.fromJson(_map(json));
  }

  @override
  Future<void> deleteMealItem(String mealId, String itemId) async {
    await _client.deleteJson('/api/v1/diet/meals/$mealId/items/$itemId');
  }

  @override
  Future<PageResult<WaterRecord>> listWater({
    DateTime? date,
    int offsetMinutes = 0,
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, String>{
      'offsetMinutes': '$offsetMinutes',
      'page': '$page',
      'size': '$size',
      if (date != null) 'date': _dateParam(date),
    };
    final json = await _client.getJson('/api/v1/diet/water', query: query);
    return PageResult.fromJson(_map(json), WaterRecord.fromJson);
  }

  @override
  Future<WaterRecord> createWater({
    required double amount,
    required String unit,
    required DateTime consumedAt,
  }) async {
    final json = await _client.postJson('/api/v1/diet/water', body: {
      'amount': amount,
      'unit': unit,
      'consumedAt': isoWithOffset(consumedAt),
    });
    return WaterRecord.fromJson(_map(json));
  }

  @override
  Future<WaterRecord> updateWater(
    String id, {
    required double amount,
    required String unit,
    required DateTime consumedAt,
  }) async {
    final json = await _client.putJson('/api/v1/diet/water/$id', body: {
      'amount': amount,
      'unit': unit,
      'consumedAt': isoWithOffset(consumedAt),
    });
    return WaterRecord.fromJson(_map(json));
  }

  @override
  Future<void> deleteWater(String id) async {
    await _client.deleteJson('/api/v1/diet/water/$id');
  }

  @override
  Future<DietSummary> dailySummary(DateTime date, {int offsetMinutes = 0}) async {
    final json = await _client.getJson('/api/v1/diet/summary', query: {
      'date': _dateParam(date),
      'offsetMinutes': '$offsetMinutes',
    });
    return DietSummary.fromJson(_map(json));
  }

  static Map<String, dynamic> _map(dynamic json) {
    if (json is Map<String, dynamic>) {
      return json;
    }
    throw ArgumentError.value(json, 'json', 'Expected a JSON object');
  }
}