import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exception.dart';
import 'package:frontend/core/money/money.dart';
import 'package:frontend/features/finance/finance_api.dart';
import 'package:frontend/features/finance/finance_controller.dart';
import 'package:frontend/features/finance/models.dart';

Account _account(String id, String name) => Account(
      id: id,
      name: name,
      type: AccountType.cash,
      currency: 'INR',
      openingBalance: Money.parse('1000'),
      balance: Money.parse('1000'),
      status: AccountStatus.active,
    );

Category _category(String id, String name) => Category(
      id: id,
      name: name,
      type: CategoryType.expense,
      status: CategoryStatus.active,
    );

FinanceTransaction _transaction(String id, String amount) =>
    FinanceTransaction(
      id: id,
      accountId: 'a1',
      accountName: 'Cash',
      accountCurrency: 'INR',
      categoryId: 'c1',
      categoryName: 'Food',
      type: TransactionType.expense,
      amount: Money.parse(amount),
      currency: 'INR',
      occurredAt: DateTime(2026, 9, 10),
      createdAt: DateTime(2026, 9, 10),
    );

Summary _summary() => Summary(
      from: DateTime(2026, 9, 1),
      to: DateTime(2026, 9, 30),
      currencies: [
        SummaryCurrencySection(
          currency: 'INR',
          income: Money.parse('5000'),
          expense: Money.parse('1200'),
          net: Money.parse('3800'),
          transferIn: Money.zero(),
          transferOut: Money.zero(),
          spendingByCategory: const [],
        ),
      ],
    );

class _FakeFinanceApi extends FinanceApi {
  _FakeFinanceApi()
      : super(
          apiClient: ApiClient(
            baseUrl: 'http://test',
            httpClient: MockClient((_) async => http.Response('{}', 200)),
          ),
        );

  List<Account> accounts = [_account('a1', 'Cash')];
  List<Category> categories = [_category('c1', 'Food')];
  List<FinanceTransaction> transactions = [_transaction('t1', '100')];
  int summaryCalls = 0;
  bool failNext = false;

  @override
  Future<List<Account>> fetchAccounts() async => List.of(accounts);

  @override
  Future<List<Category>> fetchCategories() async =>
      List.of(categories);

  @override
  Future<PageResult<FinanceTransaction>> fetchTransactions({
    String? accountId,
    String? categoryId,
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    return PageResult<FinanceTransaction>(
      items: List.of(transactions),
      page: 0,
      size: 50,
      totalElements: transactions.length,
      totalPages: 1,
      last: true,
    );
  }

  @override
  Future<PageResult<FinanceTransfer>> fetchTransfers({
    String? sourceAccountId,
    String? destinationAccountId,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 50,
  }) async {
    return PageResult<FinanceTransfer>(
      items: [],
      page: 0,
      size: 50,
      totalElements: 0,
      totalPages: 0,
      last: true,
    );
  }

  @override
  Future<Summary> fetchSummary({DateTime? from, DateTime? to}) async {
    summaryCalls++;
    return _summary();
  }

  @override
  Future<FinanceTransaction> createTransaction({
    required String accountId,
    required String categoryId,
    required TransactionType type,
    required String amount,
    DateTime? occurredAt,
    String? description,
    String? notes,
  }) async {
    if (failNext) {
      throw ApiException(400, 'BAD_REQUEST', 'Invalid amount');
    }
    final created = _transaction('t-new', amount);
    transactions = [created, ...transactions];
    return created;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    if (failNext) {
      throw ApiException(404, 'RESOURCE_NOT_FOUND', 'Not found');
    }
    transactions = transactions.where((t) => t.id != id).toList();
  }

  @override
  Future<Account> updateAccount(
    String id, {
    required String name,
    required AccountType type,
    required String currency,
    required String openingBalance,
    String? notes,
  }) async {
    final updated = _account(id, name);
    accounts = [for (final a in accounts) a.id == id ? updated : a];
    return updated;
  }
}

void main() {
  group('FinanceController mutations', () {
    test('addTransaction reloads summary and notifies dashboard',
        () async {
      int notified = 0;
      final api = _FakeFinanceApi();
      final controller = FinanceController(
        api: api,
        onMutated: () async {
          notified++;
        },
      );
      await controller.loadAll();
      final before = api.summaryCalls;

      final created = await controller.addTransaction(
        accountId: 'a1',
        categoryId: 'c1',
        type: TransactionType.expense,
        amount: '250',
      );

      expect(created.id, 't-new');
      expect(
          controller.transactions.any((t) => t.id == 't-new'), isTrue);
      // Month slices (incl. summary) reloaded after the money movement.
      expect(api.summaryCalls, greaterThan(before));
      expect(controller.summary, isNotNull);
      expect(controller.summary!.currencies.single.expense,
          Money.parse('1200'));
      expect(notified, 1);
      controller.dispose();
    });

    test('failed create skips reload and notify', () async {
      int notified = 0;
      final api = _FakeFinanceApi()..failNext = true;
      final controller = FinanceController(
        api: api,
        onMutated: () async {
          notified++;
        },
      );
      await controller.loadAll();
      final before = api.summaryCalls;

      await expectLater(
        controller.addTransaction(
          accountId: 'a1',
          categoryId: 'c1',
          type: TransactionType.expense,
          amount: 'bogus',
        ),
        throwsA(isA<ApiException>()),
      );
      expect(api.summaryCalls, before);
      expect(notified, 0);
      controller.dispose();
    });

    test('deleteTransaction removes locally and notifies', () async {
      int notified = 0;
      final api = _FakeFinanceApi();
      final controller = FinanceController(
        api: api,
        onMutated: () async {
          notified++;
        },
      );
      await controller.loadAll();
      expect(
          controller.transactions.any((t) => t.id == 't1'), isTrue);

      await controller.deleteTransaction('t1');

      expect(
          controller.transactions.any((t) => t.id == 't1'), isFalse);
      expect(notified, 1);
      controller.dispose();
    });

    test('updateAccount recomputes slices and notifies', () async {
      int notified = 0;
      final api = _FakeFinanceApi();
      final controller = FinanceController(
        api: api,
        onMutated: () async {
          notified++;
        },
      );
      await controller.loadAll();
      final before = api.summaryCalls;

      await controller.updateAccount(
        'a1',
        name: 'Cash renamed',
        type: AccountType.cash,
        currency: 'INR',
        openingBalance: '2000',
      );

      expect(controller.accountById('a1')!.name, 'Cash renamed');
      expect(api.summaryCalls, greaterThan(before));
      expect(notified, 1);
      controller.dispose();
    });

    test('summary keeps transfers out of income/expense', () async {
      final api = _FakeFinanceApi();
      final controller = FinanceController(api: api);
      await controller.loadAll();
      final section = controller.summary!.currencies.single;
      // Transfers are reported separately, never as income/expense.
      expect(section.transferIn, Money.zero());
      expect(section.transferOut, Money.zero());
      expect(section.net, Money.parse('3800'));
      controller.dispose();
    });
  });
}
