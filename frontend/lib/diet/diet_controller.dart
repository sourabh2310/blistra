import 'package:flutter/foundation.dart';

import '../core/errors.dart';
import 'diet_api.dart';
import 'models/diet_profile.dart';
import 'models/dietary_preference.dart';
import 'models/meal.dart';
import 'models/paged.dart';
import 'models/summary.dart';
import 'models/water.dart';

/// Backs the Diet feature UI. Holds the currently selected local calendar day,
/// the day's [DietSummary], the paginated history, and the diet profile, and
/// exposes every Diet action (meal CRUD, meal items, water, profile).
///
/// The client computes `offsetMinutes` from the device timezone and sends it
/// with every day-scoped request; the backend uses it to define the day
/// boundary, never the server clock.
class DietController extends ChangeNotifier {
  DietController(this._api, {void Function()? onUnauthorized})
      : _onUnauthorized = onUnauthorized;

  final DietApi _api;
  final void Function()? _onUnauthorized;

  DateTime _selectedDate = _dateOnly(DateTime.now());
  int _offsetMinutes = DateTime.now().timeZoneOffset.inMinutes;

  DietSummary? _summary;
  PageResult<MealSummary>? _history;
  DietProfile? _profile;

  bool _summaryLoading = false;
  bool _historyLoading = false;
  bool _profileLoading = false;
  String? _summaryError;
  String? _historyError;
  String? _lastActionError;

  DateTime get selectedDate => _selectedDate;

  int get offsetMinutes => _offsetMinutes;

  DietSummary? get summary => _summary;

  PageResult<MealSummary>? get history => _history;

  DietProfile? get profile => _profile;

  bool get summaryLoading => _summaryLoading;

  bool get historyLoading => _historyLoading;

  bool get profileLoading => _profileLoading;

  String? get summaryError => _summaryError;

  String? get historyError => _historyError;

  String? get lastActionError => _lastActionError;

  /// Reloads the day summary and, for the today view, the water list is part
  /// of [DietSummary]. Called on app start and when switching days.
  Future<void> loadSummary() async {
    _summaryLoading = true;
    _summaryError = null;
    notifyListeners();
    try {
      _summary = await _api.dailySummary(
        _selectedDate,
        offsetMinutes: _offsetMinutes,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
        return;
      }
      _summaryError = e.message;
    } on NetworkException {
      _summaryError = 'Cannot reach the server.';
    } catch (_) {
      _summaryError = 'Something went wrong while loading the day.';
    } finally {
      _summaryLoading = false;
      notifyListeners();
    }
  }

  void selectDate(DateTime date) {
    final onlyDate = _dateOnly(date);
    if (_sameDay(_selectedDate, onlyDate)) {
      return;
    }
    _selectedDate = onlyDate;
    _summary = null;
    _summaryError = null;
    notifyListeners();
    loadSummary();
  }

  /// Moves the selected day by [days] (typically -1 or +1).
  void shiftDate(int days) {
    selectDate(_selectedDate.add(Duration(days: days)));
  }

  Future<void> loadHistory({bool refresh = false}) async {
    if (_historyLoading) {
      return;
    }
    _historyLoading = true;
    _historyError = null;
    notifyListeners();
    try {
      final firstPage = refresh ? 0 : _history?.page ?? 0;
      final page = await _api.listMeals(offsetMinutes: _offsetMinutes, page: firstPage);
      _history = page;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
        return;
      }
      _historyError = e.message;
    } on NetworkException {
      _historyError = 'Cannot reach the server.';
    } catch (_) {
      _historyError = 'Something went wrong while loading history.';
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHistory() async {
    final current = _history;
    if (current == null || current.hasMore || _historyLoading) {
      return;
    }
    _historyLoading = true;
    notifyListeners();
    try {
      final page = await _api.listMeals(
          offsetMinutes: _offsetMinutes, page: current.page + 1);
      _history = PageResult(
        content: [...current.content, ...page.content],
        page: page.page,
        size: page.size,
        totalElements: page.totalElements,
        totalPages: page.totalPages,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
        return;
      }
      _historyError = e.message;
    } on NetworkException {
      _historyError = 'Cannot reach the server.';
    } catch (_) {
      _historyError = 'Something went wrong while loading more meals.';
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadProfile() async {
    _profileLoading = true;
    notifyListeners();
    try {
      _profile = await _api.getProfile();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
        return;
      }
      _lastActionError = e.message;
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } finally {
      _profileLoading = false;
      notifyListeners();
    }
  }

  /// Saves the profile and returns true on success.
  Future<bool> saveProfile({
    required String? dietaryPreference,
    required String? customPreference,
    required String dislikedFoods,
    required String notes,
  }) async {
    _lastActionError = null;
    notifyListeners();
    try {
      _profile = await _api.upsertProfile(DietProfile(
        dietaryPreference: dietaryPreference == null ||
                dietaryPreference.isEmpty
            ? null
            : _preferenceFromWire(dietaryPreference),
        customPreference: customPreference,
        dislikedFoods: _blankToNull(dislikedFoods),
        notes: _blankToNull(notes),
      ));
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not save the profile.';
    }
    notifyListeners();
    return false;
  }

  /// Creates a meal from raw fields. Returns the created meal, or null when
  /// creation failed.
  Future<Meal?> createMeal({
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
    required List<MealItem> items,
  }) async {
    _lastActionError = null;
    notifyListeners();
    try {
      final meal = await _api.createMeal(
        title: title,
        mealType: mealType,
        notes: notes,
        consumedAt: consumedAt,
        items: items,
      );
      notifyListeners();
      await loadSummary();
      return meal;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not save the meal.';
    }
    notifyListeners();
    return null;
  }

  /// Updates meal-level fields. Returns true on success.
  Future<bool> updateMeal({
    required String id,
    required String title,
    required String mealType,
    String? notes,
    required DateTime consumedAt,
  }) async {
    _lastActionError = null;
    notifyListeners();
    try {
      await _api.updateMeal(
        id,
        title: title,
        mealType: mealType,
        notes: notes,
        consumedAt: consumedAt,
      );
      notifyListeners();
      await loadSummary();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not update the meal.';
    }
    notifyListeners();
    return false;
  }

  Future<bool> deleteMeal(String id) async {
    _lastActionError = null;
    try {
      await _api.deleteMeal(id);
      notifyListeners();
      await loadSummary();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not delete the meal.';
    }
    notifyListeners();
    return false;
  }

  /// Loads a single meal with its items.
  Future<Meal?> fetchMeal(String id) async {
    _lastActionError = null;
    try {
      final meal = await _api.getMeal(id);
      return meal;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not load the meal.';
    }
    return null;
  }

  /// Adds an item to a meal. Returns true on success.
  Future<bool> addMealItem(String mealId, MealItem item) async {
    _lastActionError = null;
    notifyListeners();
    try {
      await _api.addMealItem(mealId, item);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not add the item.';
    }
    notifyListeners();
    return false;
  }

  /// Updates a meal item. Returns true on success.
  Future<bool> updateMealItem(
      String mealId, String itemId, MealItem item) async {
    _lastActionError = null;
    notifyListeners();
    try {
      await _api.updateMealItem(mealId, itemId, item);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not update the item.';
    }
    notifyListeners();
    return false;
  }

  /// Deletes a meal item. Returns true on success.
  Future<bool> deleteMealItem(String mealId, String itemId) async {
    _lastActionError = null;
    notifyListeners();
    try {
      await _api.deleteMealItem(mealId, itemId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not delete the item.';
    }
    notifyListeners();
    return false;
  }

  /// Records a water intake entry for the selected day. Returns true on
  /// success.
  Future<bool> addWater({
    required double amount,
    required String unit,
    DateTime? consumedAt,
  }) async {
    _lastActionError = null;
    notifyListeners();
    try {
      final at = consumedAt ?? DateTime.now();
      if (at.isAfter(DateTime.now())) {
        _lastActionError = 'Water time cannot be in the future.';
        notifyListeners();
        return false;
      }
      await _api.createWater(amount: amount, unit: unit, consumedAt: at);
      notifyListeners();
      await loadSummary();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not save the water record.';
    }
    notifyListeners();
    return false;
  }

  /// Deletes a water record. Returns true on success.
  Future<bool> deleteWater(String id) async {
    _lastActionError = null;
    notifyListeners();
    try {
      await _api.deleteWater(id);
      notifyListeners();
      await loadSummary();
      return true;
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        _handleUnauthorized();
      } else {
        _lastActionError = e.message;
      }
    } on NetworkException {
      _lastActionError = 'Cannot reach the server.';
    } catch (_) {
      _lastActionError = 'Could not delete the water record.';
    }
    notifyListeners();
    return false;
  }

  void _handleUnauthorized() {
    _onUnauthorized?.call();
  }

  static DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static DietaryPreference _preferenceFromWire(String wire) =>
      DietaryPreference.fromWire(wire);
}