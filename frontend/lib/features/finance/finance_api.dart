/// Typed client for the finance REST API.
library;

import '../../core/api/api_client.dart';
import 'models.dart';

class FinanceApi {
  FinanceApi({required this.apiClient});

  final ApiClient apiClient;

  Future<List<Account>> fetchAccounts() async {
    final List<dynamic> body = await apiClient.getList(
        '/api/v1/finance/accounts');
    return body
        .map((Object? item) => Account.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Account> createAccount({
    required String name,
    required AccountType type,
    required String currency,
    required String openingBalance,
    String? notes,
  }) async {
    final Map<String, dynamic> body = await apiClient.post(
      '/api/v1/finance/accounts',
      body: {
        'name': name,
        'type': enumToJson(type),
        'currency': currency.toUpperCase(),
        'openingBalance': openingBalance,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return Account.fromJson(body);
  }

  Future<Account> updateAccount(
    String id, {
    required String name,
    required AccountType type,
    required String currency,
    required String openingBalance,
    String? notes,
  }) async {
    final Map<String, dynamic> body = await apiClient.put(
      '/api/v1/finance/accounts/$id',
      body: {
        'name': name,
        'type': enumToJson(type),
        'currency': currency.toUpperCase(),
        'openingBalance': openingBalance,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return Account.fromJson(body);
  }

  Future<void> archiveAccount(String id) async {
    await apiClient.delete('/api/v1/finance/accounts/$id');
  }

  Future<List<Category>> fetchCategories() async {
    final List<dynamic> body = await apiClient.getList(
        '/api/v1/finance/categories');
    return body
        .map((Object? item) => Category.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Category> createCategory({
    required String name,
    required CategoryType type,
  }) async {
    final Map<String, dynamic> body = await apiClient.post(
      '/api/v1/finance/categories',
      body: {'name': name, 'type': enumToJson(type)},
    );
    return Category.fromJson(body);
  }

  Future<Category> updateCategory(
    String id, {
    required String name,
    required CategoryType type,
  }) async {
    final Map<String, dynamic> body = await apiClient.put(
      '/api/v1/finance/categories/$id',
      body: {'name': name, 'type': enumToJson(type)},
    );
    return Category.fromJson(body);
  }

  Future<void> archiveCategory(String id) async {
    await apiClient.delete('/api/v1/finance/categories/$id');
  }

  Future<PageResult<FinanceTransaction>> fetchTransactions({
    String? accountId,
    String? categoryId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final Map<String, dynamic> body = await apiClient.get(
      '/api/v1/finance/transactions',
      query: {
        if (accountId != null) 'accountId': accountId,
        if (categoryId != null) 'categoryId': categoryId,
        if (type != null) 'type': enumToJson(type),
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        'page': '$page',
        'size': '$size',
      },
    );
    return PageResult.fromJson(body, FinanceTransaction.fromJson);
  }

  Future<FinanceTransaction> createTransaction({
    required String accountId,
    required String categoryId,
    required TransactionType type,
    required String amount,
    DateTime? occurredAt,
    String? description,
    String? notes,
  }) async {
    final Map<String, dynamic> body = await apiClient.post(
      '/api/v1/finance/transactions',
      body: {
        'accountId': accountId,
        'categoryId': categoryId,
        'type': enumToJson(type),
        'amount': amount,
        if (occurredAt != null) 'occurredAt': _dateOnly(occurredAt),
        if (description != null && description.isNotEmpty)
          'description': description,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return FinanceTransaction.fromJson(body);
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
    final Map<String, dynamic> body = await apiClient.put(
      '/api/v1/finance/transactions/$id',
      body: {
        'accountId': accountId,
        'categoryId': categoryId,
        'type': enumToJson(type),
        'amount': amount,
        'occurredAt': _dateOnly(occurredAt),
        if (description != null && description.isNotEmpty)
          'description': description,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return FinanceTransaction.fromJson(body);
  }

  Future<void> deleteTransaction(String id) async {
    await apiClient.delete('/api/v1/finance/transactions/$id');
  }

  Future<PageResult<FinanceTransfer>> fetchTransfers({
    String? sourceAccountId,
    String? destinationAccountId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    final Map<String, dynamic> body = await apiClient.get(
      '/api/v1/finance/transfers',
      query: {
        if (sourceAccountId != null) 'sourceAccountId': sourceAccountId,
        if (destinationAccountId != null)
          'destinationAccountId': destinationAccountId,
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
        'page': '$page',
        'size': '$size',
      },
    );
    return PageResult.fromJson(body, FinanceTransfer.fromJson);
  }

  Future<FinanceTransfer> createTransfer({
    required String sourceAccountId,
    required String destinationAccountId,
    required String amount,
    DateTime? transferredAt,
    String? note,
  }) async {
    final Map<String, dynamic> body = await apiClient.post(
      '/api/v1/finance/transfers',
      body: {
        'sourceAccountId': sourceAccountId,
        'destinationAccountId': destinationAccountId,
        'amount': amount,
        if (transferredAt != null) 'transferredAt': _dateOnly(transferredAt),
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return FinanceTransfer.fromJson(body);
  }

  Future<void> deleteTransfer(String id) async {
    await apiClient.delete('/api/v1/finance/transfers/$id');
  }

  Future<Summary> fetchSummary({DateTime? from, DateTime? to}) async {
    final Map<String, dynamic> body = await apiClient.get(
      '/api/v1/finance/summary',
      query: {
        if (from != null) 'from': _dateOnly(from),
        if (to != null) 'to': _dateOnly(to),
      },
    );
    return Summary.fromJson(body);
  }

  static String _dateOnly(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}