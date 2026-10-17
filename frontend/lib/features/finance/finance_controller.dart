/// Application state for Finance: the month being viewed (overview +
/// expenses), friends and requests, and the user's default currency.
///
/// Every mutation goes through here, then re-fetches the affected slices from
/// the backend (the source of truth) and notifies [onMutated] so Home can
/// refresh its finance card.
library;

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_exception.dart';
import 'finance_api.dart';
import 'models.dart';

enum FinanceLoadStatus { idle, loading, ready, error }

class FinanceController extends ChangeNotifier {
  FinanceController({required this.api, this.onMutated});

  final FinanceApi api;

  /// Invoked after a successful mutation (e.g. to refresh the Home dashboard).
  final Future<void> Function()? onMutated;

  static const String _currencyKey = 'finance.defaultCurrency';
  static const List<String> commonCurrencies = [
    'INR', 'USD', 'EUR', 'GBP', 'AED', 'SGD', 'AUD', 'CAD', 'JPY',
  ];
  static const int _pageSize = 50;

  FinanceLoadStatus _status = FinanceLoadStatus.idle;
  String? _errorMessage;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  FinanceOverview? _overview;
  List<Expense> _expenses = const [];
  bool _expensesLast = true;
  int _expensesPage = 0;
  bool _loadingMore = false;
  FriendsData _friends = FriendsData.empty;
  String _currency = 'INR';
  bool _currencyLoaded = false;

  FinanceLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == FinanceLoadStatus.loading;
  DateTime get month => _month;
  FinanceOverview? get overview => _overview;
  List<Expense> get expenses => _expenses;
  bool get hasMoreExpenses => !_expensesLast;
  bool get loadingMore => _loadingMore;
  FriendsData get friends => _friends;
  UserSummary? get me => _friends.me;
  String get currency => _currency;

  bool get isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  DateTime get monthEnd => DateTime(_month.year, _month.month + 1, 0);

  /// Overview for the default currency (or the first one with activity).
  CurrencyOverview? get primaryOverview {
    final list = _overview?.currencies ?? const [];
    for (final c in list) {
      if (c.currency == _currency) return c;
    }
    return list.isEmpty ? null : list.first;
  }

  Friend? friendById(String userId) {
    for (final f in _friends.friends) {
      if (f.user.id == userId) return f;
    }
    return null;
  }

  Future<void> loadAll() async {
    _status = FinanceLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await Future.wait([
        _loadCurrency(),
        _loadOverview(),
        _loadExpenses(),
        _loadFriends(),
      ]);
      _status = FinanceLoadStatus.ready;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = FinanceLoadStatus.error;
    } catch (e) {
      _errorMessage = 'Something went wrong loading Finance.';
      _status = FinanceLoadStatus.error;
    }
    notifyListeners();
  }

  /// Pull-to-refresh: reload everything without blanking the screen.
  Future<void> refresh() async {
    try {
      await Future.wait([_loadOverview(), _loadExpenses(), _loadFriends()]);
      _errorMessage = null;
      _status = FinanceLoadStatus.ready;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Could not refresh Finance.';
    }
    notifyListeners();
  }

  Future<void> shiftMonth(int delta) async {
    final next = DateTime(_month.year, _month.month + delta);
    final now = DateTime.now();
    if (next.isAfter(DateTime(now.year, now.month))) return;
    _month = next;
    _overview = null;
    _expenses = const [];
    notifyListeners();
    try {
      await Future.wait([_loadOverview(), _loadExpenses()]);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
    notifyListeners();
  }

  Future<void> loadMoreExpenses() async {
    if (_expensesLast || _loadingMore) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final page = await api.expenses(
        from: _month,
        to: monthEnd,
        page: _expensesPage + 1,
        size: _pageSize,
      );
      _expensesPage += 1;
      _expenses = [..._expenses, ...page.items];
      _expensesLast = page.last;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> setCurrency(String code) async {
    _currency = code;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyKey, code);
    } catch (_) {
      // Preference is a convenience; ignore storage failures.
    }
  }

  // ---------------------------------------------------------------- mutations

  Future<Expense> saveExpense(ExpenseDraft draft, {String? id}) async {
    final saved = id == null ? await api.createExpense(draft) : await api.updateExpense(id, draft);
    if (draft.currency != _currency && id == null) {
      await setCurrency(draft.currency);
    }
    await _afterMutation(friends: draft.splitType != SplitType.none);
    return saved;
  }

  Future<void> deleteExpense(Expense expense) async {
    await api.deleteExpense(expense.id);
    await _afterMutation(friends: expense.isShared);
  }

  /// Returns "PENDING" or "ACCEPTED".
  Future<String> addFriend(String username) async {
    final status = await api.addFriend(username);
    await _loadFriends();
    notifyListeners();
    return status;
  }

  Future<void> acceptRequest(FriendRequest request) async {
    await api.acceptRequest(request.id);
    await Future.wait([_loadFriends(), _loadOverview()]);
    notifyListeners();
  }

  Future<void> dismissRequest(FriendRequest request) async {
    await api.dismissRequest(request.id);
    await _loadFriends();
    notifyListeners();
  }

  Future<void> removeFriend(String userId) async {
    await api.removeFriend(userId);
    await Future.wait([_loadFriends(), _loadOverview()]);
    notifyListeners();
  }

  Future<void> settleUp({
    required String friendId,
    required bool iPaid,
    required String amount,
    required String currency,
    DateTime? on,
    String? note,
  }) async {
    await api.settleUp(
      friendId: friendId,
      iPaid: iPaid,
      amount: amount,
      currency: currency,
      on: on,
      note: note,
    );
    await _afterMutation(friends: true);
  }

  Future<void> deleteSettlement(Settlement settlement) async {
    await api.deleteSettlement(settlement.id);
    await _afterMutation(friends: true);
  }

  Future<void> saveBudget({ExpenseCategory? category, required String currency, required String limit}) async {
    await api.saveBudget(category: category, currency: currency, monthlyLimit: limit);
    await _loadOverview();
    notifyListeners();
  }

  Future<void> deleteBudget(Budget budget) async {
    await api.deleteBudget(budget.id);
    await _loadOverview();
    notifyListeners();
  }

  // ---------------------------------------------------------------- loading

  Future<void> _afterMutation({required bool friends}) async {
    try {
      await Future.wait([
        _loadOverview(),
        _loadExpenses(),
        if (friends) _loadFriends(),
      ]);
    } catch (_) {
      // The mutation itself succeeded; a later refresh will catch up.
    }
    notifyListeners();
    final callback = onMutated;
    if (callback != null) {
      try {
        await callback();
      } catch (_) {
        // Never let a Home refresh failure break Finance.
      }
    }
  }

  Future<void> _loadCurrency() async {
    if (_currencyLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_currencyKey);
      if (saved != null && saved.length == 3) _currency = saved;
    } catch (_) {
      // Fall back to the default.
    }
    _currencyLoaded = true;
  }

  Future<void> _loadOverview() async {
    final month = _month;
    final overview = await api.overview(month);
    if (month == _month) _overview = overview;
  }

  Future<void> _loadExpenses() async {
    final month = _month;
    final page = await api.expenses(from: month, to: DateTime(month.year, month.month + 1, 0), size: _pageSize);
    if (month != _month) return;
    _expenses = page.items;
    _expensesLast = page.last;
    _expensesPage = 0;
  }

  Future<void> _loadFriends() async {
    _friends = await api.friends();
  }
}
