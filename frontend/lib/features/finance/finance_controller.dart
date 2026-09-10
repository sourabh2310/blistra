/// Application state for the finance feature.
///
/// [FinanceController] owns all finance data currently on screen, exposes it
/// to the UI via notifications, and is the single path through which every
/// mutation reaches the backend. After each successful mutation the affected
/// slices (accounts, summary, transactions) are re-fetched from the backend,
/// which is the source of truth.
library;

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'finance_api.dart';
import 'models.dart';

enum FinanceLoadStatus { idle, loading, ready, error }

class FinanceController extends ChangeNotifier {
  FinanceController({required this.api});

  final FinanceApi api;

  FinanceLoadStatus _status = FinanceLoadStatus.idle;
  String? _errorMessage;

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  List<FinanceTransaction> _transactions = const [];
  List<FinanceTransfer> _transfers = const [];
  Summary? _summary;

  DateTime _from = _firstOfMonth(DateTime.now());
  DateTime _to = _lastOfMonth(DateTime.now());

  FinanceLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;

  List<Account> get accounts => _accounts;
  List<Category> get categories => _categories;
  List<FinanceTransaction> get transactions => _transactions;
  List<FinanceTransfer> get transfers => _transfers;
  Summary? get summary => _summary;

  DateTime get from => _from;
  DateTime get to => _to;

  bool get hasAccounts => _accounts.isNotEmpty;

  bool get isLoading => _status == FinanceLoadStatus.loading;

  List<Account> get activeAccounts =>
      _accounts.where((Account a) => !a.isArchived).toList();

  List<Category> get activeCategories =>
      _categories.where((Category c) => !c.isArchived).toList();

  List<Category> categoriesOfType(CategoryType type) =>
      activeCategories.where((Category c) => c.type == type).toList();

  Account? accountById(String id) {
    for (final Account account in _accounts) {
      if (account.id == id) {
        return account;
      }
    }
    return null;
  }

  Category? categoryById(String id) {
    for (final Category category in _categories) {
      if (category.id == id) {
        return category;
      }
    }
    return null;
  }

  /// Sets the reporting month and reloads the month-scoped data.
  Future<void> setRange(DateTime from, DateTime to) async {
    _from = from;
    _to = to;
    notifyListeners();
    await loadMonthData();
  }

  Future<void> loadAll() async {
    _status = FinanceLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await Future.wait([
        _loadAccounts(),
        _loadCategories(),
        _loadMonthTransactions(),
        _loadMonthTransfers(),
        _loadSummary(),
      ]);
      _status = FinanceLoadStatus.ready;
    } on ApiException catch (error) {
      _errorMessage = error.toString();
      _status = FinanceLoadStatus.error;
    }
    notifyListeners();
  }

  /// Reloads the month-scoped slices (summary, transactions, transfers)
  /// without rebuilding accounts/categories.
  Future<void> loadMonthData() async {
    _status = FinanceLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      await Future.wait([
        _loadMonthTransactions(),
        _loadMonthTransfers(),
        _loadSummary(),
      ]);
      _status = FinanceLoadStatus.ready;
    } on ApiException catch (error) {
      _errorMessage = error.toString();
      _status = FinanceLoadStatus.error;
    }
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Accounts
  // -------------------------------------------------------------------------

  Future<Account> addAccount({
    required String name,
    required AccountType type,
    required String currency,
    required String openingBalance,
    String? notes,
  }) async {
    final Account created = await api.createAccount(
      name: name,
      type: type,
      currency: currency,
      openingBalance: openingBalance,
      notes: notes,
    );
    _accounts = [..._accounts, created];
    notifyListeners();
    await _refreshSensitiveSlices();
    return created;
  }

  Future<Account> updateAccount(
    String id, {
    required String name,
    required AccountType type,
    required String currency,
    required String openingBalance,
    String? notes,
  }) async {
    final Account updated = await api.updateAccount(
      id,
      name: name,
      type: type,
      currency: currency,
      openingBalance: openingBalance,
      notes: notes,
    );
    _accounts = [for (final Account a in _accounts) a.id == id ? updated : a];
    notifyListeners();
    return updated;
  }

  Future<void> archiveAccount(String id) async {
    await api.archiveAccount(id);
    await _refreshSensitiveSlices();
    await _loadAccounts();
  }

  // -------------------------------------------------------------------------
  // Categories
  // -------------------------------------------------------------------------

  Future<Category> addCategory({
    required String name,
    required CategoryType type,
  }) async {
    final Category created = await api.createCategory(name: name, type: type);
    _categories = [..._categories, created]..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return created;
  }

  Future<Category> updateCategory(
    String id, {
    required String name,
    required CategoryType type,
  }) async {
    final Category updated = await api.updateCategory(id, name: name, type: type);
    _categories =
        [for (final Category c in _categories) c.id == id ? updated : c]
          ..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return updated;
  }

  Future<void> archiveCategory(String id) async {
    await api.archiveCategory(id);
    await _loadCategories();
  }

  // -------------------------------------------------------------------------
  // Transactions
  // -------------------------------------------------------------------------

  Future<FinanceTransaction> addTransaction({
    required String accountId,
    required String categoryId,
    required TransactionType type,
    required String amount,
    DateTime? occurredAt,
    String? description,
    String? notes,
  }) async {
    final FinanceTransaction created = await api.createTransaction(
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      occurredAt: occurredAt ?? _to,
      description: description,
      notes: notes,
    );
    _transactions = [created, ..._transactions]..sort(_compareNewestFirst);
    notifyListeners();
    await _refreshSensitiveSlices();
    return created;
  }

  Future<FinanceTransaction> updateTransaction(
    String id, {
    required String accountId,
    required String categoryId,
    required TransactionType type,
    required String amount,
    required DateTime occurredAt,
    String? description,
    String? notes,
  }) async {
    final FinanceTransaction updated = await api.updateTransaction(
      id,
      accountId: accountId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      occurredAt: occurredAt,
      description: description,
      notes: notes,
    );
    _transactions = [
      for (final FinanceTransaction t in _transactions) t.id == id ? updated : t,
    ]..sort(_compareNewestFirst);
    notifyListeners();
    await _refreshSensitiveSlices();
    return updated;
  }

  Future<void> deleteTransaction(String id) async {
    await api.deleteTransaction(id);
    _transactions =
        _transactions.where((FinanceTransaction t) => t.id != id).toList();
    notifyListeners();
    await _refreshSensitiveSlices();
  }

  // -------------------------------------------------------------------------
  // Transfers
  // -------------------------------------------------------------------------

  Future<FinanceTransfer> addTransfer({
    required String sourceAccountId,
    required String destinationAccountId,
    required String amount,
    DateTime? transferredAt,
    String? note,
  }) async {
    final FinanceTransfer created = await api.createTransfer(
      sourceAccountId: sourceAccountId,
      destinationAccountId: destinationAccountId,
      amount: amount,
      transferredAt: transferredAt ?? _to,
      note: note,
    );
    _transfers = [created, ..._transfers]..sort(_compareTransferNewestFirst);
    notifyListeners();
    await _refreshSensitiveSlices();
    return created;
  }

  Future<void> deleteTransfer(String id) async {
    await api.deleteTransfer(id);
    _transfers =
        _transfers.where((FinanceTransfer t) => t.id != id).toList();
    notifyListeners();
    await _refreshSensitiveSlices();
  }

  // -------------------------------------------------------------------------

  Future<void> _loadAccounts() async {
    _accounts = await api.fetchAccounts();
  }

  Future<void> _loadCategories() async {
    _categories = await api.fetchCategories();
  }

  Future<void> _loadMonthTransactions() async {
    final PageResult<FinanceTransaction> result =
        await api.fetchTransactions(from: _from, to: _to, size: 200);
    _transactions = result.items..sort(_compareNewestFirst);
  }

  Future<void> _loadMonthTransfers() async {
    final PageResult<FinanceTransfer> result =
        await api.fetchTransfers(from: _from, to: _to, size: 200);
    _transfers = result.items..sort(_compareTransferNewestFirst);
  }

  Future<void> _loadSummary() async {
    _summary = await api.fetchSummary(from: _from, to: _to);
  }

  /// Refreshes everything affected by a money movement so the UI never shows
  /// a stale balance.
  Future<void> _refreshSensitiveSlices() async {
    await Future.wait([
      _loadAccounts(),
      _loadMonthTransactions(),
      _loadMonthTransfers(),
      _loadSummary(),
    ]);
    notifyListeners();
  }

  static int _compareNewestFirst(FinanceTransaction a, FinanceTransaction b) {
    final int byDate = b.occurredAt.compareTo(a.occurredAt);
    if (byDate != 0) {
      return byDate;
    }
    return b.createdAt.compareTo(a.createdAt);
  }

  static int _compareTransferNewestFirst(FinanceTransfer a, FinanceTransfer b) {
    return b.transferredAt.compareTo(a.transferredAt);
  }

  static DateTime _firstOfMonth(DateTime value) =>
      DateTime(value.year, value.month);

  static DateTime _lastOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1, 0);
}