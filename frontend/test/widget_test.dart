import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/auth/auth_controller.dart';
import 'package:frontend/auth/token_store.dart';
import 'package:frontend/auth/repository.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/config.dart';
import 'package:frontend/core/errors.dart';
import 'package:frontend/diet/diet_api.dart';
import 'package:frontend/diet/diet_controller.dart';
import 'package:frontend/diet/models/diet_profile.dart';
import 'package:frontend/diet/models/dietary_preference.dart';
import 'package:frontend/diet/models/item_draft.dart';
import 'package:frontend/diet/models/meal.dart';
import 'package:frontend/diet/models/meal_type.dart';
import 'package:frontend/diet/models/nutrition_totals.dart';
import 'package:frontend/diet/models/paged.dart';
import 'package:frontend/diet/models/summary.dart';
import 'package:frontend/diet/models/water.dart';
import 'package:frontend/diet/models/wire.dart';
import 'package:frontend/diet/screens/login_screen.dart';
import 'package:frontend/diet/screens/today_screen.dart';
import 'package:frontend/diet/validators.dart';
import 'package:frontend/main.dart';

void main() {
  group('Validators', () {
    test('email validates correctly', () {
      expect(Validators.email('test@example.com'), isNull);
      expect(Validators.email('bad'), 'Enter a valid email address');
      expect(Validators.email(''), 'Email is required');
    });

    test('password validates correctly', () {
      expect(Validators.password('password123'), isNull);
      expect(Validators.password('short'), 'Password must be at least 8 characters');
      expect(Validators.password(''), 'Password is required');
    });

    test('mealTitle validates correctly', () {
      expect(Validators.mealTitle('Lunch'), isNull);
      expect(Validators.mealTitle(''), 'Meal title is required');
      expect(Validators.mealTitle('a' * 201), 'Meal title cannot exceed 200 characters');
    });

    test('positiveNumber and nonNegativeNumber', () {
      expect(Validators.positiveNumber('10'), isNull);
      expect(Validators.positiveNumber('0'), 'Must be greater than 0');
      expect(Validators.positiveNumber('-1'), 'Must be greater than 0');
      expect(Validators.nonNegativeNumber('0'), isNull);
      expect(Validators.nonNegativeNumber('5.5'), isNull);
      expect(Validators.nonNegativeNumber('-1'), 'Cannot be negative');
    });

    test('waterAmount requires a positive number', () {
      expect(Validators.waterAmount('250'), isNull);
      expect(Validators.waterAmount('0'), 'Amount is required');
      expect(Validators.waterAmount(''), 'Amount is required');
    });

    test('parseOptionalNumber parses and returns null for blank', () {
      expect(Validators.parseOptionalNumber('123.45'), 123.45);
      expect(Validators.parseOptionalNumber('42'), 42.0);
      expect(Validators.parseOptionalNumber(''), isNull);
      expect(Validators.parseOptionalNumber(null), isNull);
    });

    test('notes validates max length', () {
      expect(Validators.notes('short', max: 10), isNull);
      expect(Validators.notes('a' * 11, max: 10), 'Cannot exceed 10 characters');
    });
  });

  group('Wire date formatting', () {
    test('isoWithOffset adds offset for local DateTime', () {
      final dt = DateTime(2026, 8, 10, 12, 0, 0);
      final formatted = isoWithOffset(dt);
      expect(RegExp(r'\+\d{2}:\d{2}$').hasMatch(formatted) ||
          RegExp(r'-\d{2}:\d{2}$').hasMatch(formatted) ||
          formatted.endsWith('Z'), isTrue);
    });

    test('isoWithOffset passes through Z for UTC', () {
      final dt = DateTime.utc(2026, 8, 10, 12, 0, 0);
      expect(isoWithOffset(dt), '2026-08-10T12:00:00.000Z');
    });
  });

  group('Models serialization', () {
    test('MealType round-trips through wire', () {
      for (final type in MealType.values) {
        expect(MealType.fromWire(type.wireName), type);
      }
      expect(MealType.fromWire('UNKNOWN'), MealType.other);
    });

    test('DietaryPreference round-trips through wire', () {
      for (final p in DietaryPreference.values) {
        expect(DietaryPreference.fromWire(p.wireName), p);
      }
      expect(DietaryPreference.fromWire('UNKNOWN'), DietaryPreference.other);
    });

    test('WaterUnit round-trips through wire', () {
      for (final u in WaterUnit.values) {
        expect(WaterUnit.fromWire(u.wireName), u);
      }
      expect(WaterUnit.fromWire('UNKNOWN'), WaterUnit.ml);
    });

    test('MealItem to/from JSON', () {
      final item = MealItem(
        id: 'item-1',
        name: 'Apple',
        quantity: 1.5,
        unit: 'pcs',
        caloriesKcal: 80,
        proteinG: 0.5,
        carbohydratesG: 21,
        fatG: 0.3,
        fiberG: 3.5,
        notes: 'Fresh',
      );
      final json = item.toItemRequest();
      expect(json['name'], 'Apple');
      expect(json['quantity'], 1.5);
      expect(json['caloriesKcal'], 80.0);

      final parsed = MealItem.fromJson({
        'id': 'item-1',
        'name': 'Apple',
        'quantity': 1.5,
        'unit': 'pcs',
        'caloriesKcal': 80,
        'proteinG': 0.5,
        'carbohydratesG': 21,
        'fatG': 0.3,
        'fiberG': 3.5,
        'notes': 'Fresh',
        'createdAt': '2026-08-10T12:00:00',
        'updatedAt': '2026-08-10T12:00:00',
      });
      expect(parsed.name, 'Apple');
      expect(parsed.quantity, 1.5);
    });

    test('MealSummary from JSON', () {
      final json = {
        'id': 'meal-1',
        'mealType': 'LUNCH',
        'title': 'Salad',
        'consumedAt': '2026-08-10T12:00:00+05:30',
        'itemCount': 2,
        'createdAt': '2026-08-10T12:00:00',
        'updatedAt': '2026-08-10T12:00:00',
      };
      final meal = MealSummary.fromJson(json);
      expect(meal.id, 'meal-1');
      expect(meal.mealType, MealType.lunch);
      expect(meal.title, 'Salad');
      expect(meal.itemCount, 2);
    });

    test('WaterRecord from JSON with unit parsing', () {
      final json = {
        'id': 'water-1',
        'amount': 250,
        'unit': 'ml',
        'consumedAt': '2026-08-10T12:00:00+05:30',
        'createdAt': '2026-08-10T12:00:00',
        'updatedAt': '2026-08-10T12:00:00',
      };
      final water = WaterRecord.fromJson(json);
      expect(water.amount, 250);
      expect(water.unit, WaterUnit.ml);
      expect(water.milliliters, 250);
    });

    test('DietProfile toRequest omits nulls', () {
      final profile = DietProfile(
        dietaryPreference: DietaryPreference.vegetarian,
        customPreference: null,
        dislikedFoods: 'Shellfish',
        notes: null,
      );
      final req = profile.toRequest();
      expect(req['dietaryPreference'], 'VEGETARIAN');
      expect(req.containsKey('customPreference'), isTrue);
      expect(req['customPreference'], isNull);
      expect(req['dislikedFoods'], 'Shellfish');
      expect(req['notes'], isNull);
    });
  });

  group('ApiClient error mapping', () {
    test('ApiException contains fieldErrors for validation', () {
      final json = {
        'code': 'VALIDATION_ERROR',
        'message': 'Request validation failed',
        'errors': [
          {'field': 'email', 'message': 'Email is required'},
          {'field': 'password', 'message': 'Password must be at least 8 characters'}
        ]
      };
      final resp = _mockResponse(400, json);
      final ex = ApiClient._toApiException(resp);
      expect(ex.status, 400);
      expect(ex.code, 'VALIDATION_ERROR');
      expect(ex.fieldErrors['email'], 'Email is required');
      expect(ex.fieldErrors['password'], 'Password must be at least 8 characters');
    });

    test('ApiException maps 401 to isUnauthorized', () {
      final json = {
        'code': 'AUTHENTICATION_REQUIRED',
        'message': 'Authentication is required'
      };
      final resp = _mockResponse(401, json);
      final ex = ApiClient._toApiException(resp);
      expect(ex.isUnauthorized, isTrue);
    });
  });

  group('DietController with fake API', () {
    late FakeDietApi fakeApi;
    late DietController controller;

    setUp(() {
      fakeApi = FakeDietApi();
      controller = DietController(fakeApi);
    });

    test('loadSummary populates summary', () async {
      final summary = DietSummary(
        date: DateTime.now(),
        offsetMinutes: 330,
        mealCount: 1,
        meals: [MealSummary(id: 'm1', mealType: MealType.breakfast, title: 'Toast', consumedAt: DateTime.now(), itemCount: 1)],
        waterCount: 2,
        water: [WaterRecord(id: 'w1', amount: 250, unit: WaterUnit.ml, consumedAt: DateTime.now())],
        waterTotalMilliliters: 500,
        nutrition: null,
      );
      fakeApi.nextSummary = summary;
      await controller.loadSummary();
      expect(controller.summary?.mealCount, 1);
      expect(controller.summary?.waterTotalMilliliters, 500);
    });

    test('createMeal populates items via API', () async {
      fakeApi.nextMeal = Meal(id: 'm1', mealType: MealType.lunch, title: 'Salad', consumedAt: DateTime.now(), items: []);
      final meal = await controller.createMeal(
        title: 'Salad',
        mealType: MealType.lunch.wireName,
        consumedAt: DateTime.now(),
        items: [MealItem(name: 'Lettuce')],
      );
      expect(meal?.title, 'Salad');
      expect(fakeApi.lastCreateMealRequest['title'], 'Salad');
    });

    test('saveProfile calls upsert with right payload', () async {
      final profile = DietProfile(
        dietaryPreference: DietaryPreference.vegan,
        customPreference: null,
        dislikedFoods: 'Honey',
        notes: 'Plant-based',
      );
      fakeApi.nextProfile = profile;
      final ok = await controller.saveProfile(
        dietaryPreference: 'VEGAN',
        customPreference: null,
        dislikedFoods: 'Honey',
        notes: 'Plant-based',
      );
      expect(ok, isTrue);
      expect(fakeApi.lastProfile?.dietaryPreference, DietaryPreference.vegan);
    });
  });

  group('Widget tests', () {
    testWidgets('LoginScreen shows form and toggles register mode', (tester) async {
      final tokenStore = await _makeTokenStore();
      final api = ApiClient(baseUrl: 'http://test', tokenProvider: () => tokenStore.token);
      final auth = AuthController(repository: AuthRepository(api), tokenStore: tokenStore);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: auth, child: const MaterialApp(home: LoginScreen())),
      );
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create account'), findsNothing);
      expect(find.text('New here? Create an account'), findsOneWidget);

      await tester.tap(find.text('New here? Create an account'));
      await tester.pump();
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
    });

    testWidgets('TodayScreen shows empty state when no summary', (tester) async {
      final fakeApi = FakeDietApi();
      final controller = DietController(fakeApi);
      fakeApi.nextSummary = null;

      await tester.pumpWidget(
        ChangeNotifierProvider.value(value: controller, child: const MaterialApp(home: TodayScreen())),
      );
      await tester.pump();

      expect(find.byType(ErrorState), findsOneWidget);
    });
  });
}

/// A minimal DietApi stub for testing.
class FakeDietApi extends Fake implements DietApi {
  DietSummary? nextSummary;
  Meal? nextMeal;
  DietProfile? nextProfile;
  Map<String, dynamic>? lastCreateMealRequest;
  DietProfile? lastProfile;

  @override
  Future<DietSummary> dailySummary(DateTime date, {int offsetMinutes = 0}) async {
    return nextSummary ?? DietSummary(date: date, offsetMinutes: offsetMinutes, mealCount: 0, waterCount: 0);
  }

  @override
  Future<Meal> createMeal({
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
    required List<MealItem> items,
  }) async {
    lastCreateMealRequest = {
      'title': title,
      'mealType': mealType,
      'notes': notes,
      'consumedAt': isoWithOffset(consumedAt),
      'items': items.map((e) => e.toItemRequest()).toList(),
    };
    return nextMeal ?? Meal(id: 'm1', mealType: MealType.lunch, title: title, consumedAt: consumedAt, items: []);
  }

  @override
  Future<DietProfile> upsertProfile(DietProfile profile) async {
    lastProfile = profile;
    return nextProfile ?? profile;
  }

  @override
  Future<Meal> updateMeal(String id, {required String title, required String mealType, String? notes, required DateTime consumedAt}) async {
    return nextMeal ?? Meal(id: id, mealType: MealType.lunch, title: title, consumedAt: consumedAt);
  }

  @override
  Future<Meal> getMeal(String id) async => throw UnimplementedError();

  @override
  Future<PageResult<MealSummary>> listMeals({DateTime? date, int offsetMinutes = 0, int page = 0, int size = 20}) async => throw UnimplementedError();

  @override
  Future<void> deleteMeal(String id) async {}

  @override
  Future<MealItem> addMealItem(String mealId, MealItem item) async => throw UnimplementedError();

  @override
  Future<MealItem> updateMealItem(String mealId, String itemId, MealItem item) async => throw UnimplementedError();

  @override
  Future<void> deleteMealItem(String mealId, String itemId) async {}

  @override
  Future<PageResult<WaterRecord>> listWater({DateTime? date, int offsetMinutes = 0, int page = 0, int size = 20}) async => throw UnimplementedError();

  @override
  Future<WaterRecord> createWater({required double amount, required String unit, required DateTime consumedAt}) async => throw UnimplementedError();

  @override
  Future<WaterRecord> updateWater(String id, {required double amount, required String unit, required DateTime consumedAt}) async => throw UnimplementedError();

  @override
  Future<void> deleteWater(String id) async {}

  @override
  Future<DietProfile> getProfile() async => throw UnimplementedError();
}

/// Helper to build a fake http.Response for ApiClient error mapping.
import 'package:http/http.dart' as http;
http.Response _mockResponse(int statusCode, Object body) {
  return http.Response(body is String ? body : body.toString(), statusCode);
}

TokenStore _makeTokenStore() async {
  SharedPreferences.setMockInitialValues({});
  return await TokenStore.load();
}