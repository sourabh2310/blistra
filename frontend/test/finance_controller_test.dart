import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/finance/finance_api.dart';
import 'package:frontend/features/finance/finance_controller.dart';
import 'package:frontend/features/finance/models.dart';

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

/// Minimal fake backend: one month of data, records which paths were hit.
class _FakeBackend {
  final List<String> calls = [];
  int expensesCreated = 0;
  bool failOverview = false;

  MockClient get client => MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        final path = request.url.path;
        if (path == '/api/v1/finance/overview') {
          if (failOverview) return _json({'code': 'X', 'message': 'Overview down'}, status: 500);
          return _json({
            'from': '2026-10-01',
            'currencies': [
              {
                'currency': 'INR',
                'spent': '${100 * expensesCreated}.0000',
                'paid': '0.0000',
                'previousMonthSpent': '0.0000',
                'todaySpent': '0.0000',
                'byCategory': [],
                'daily': [],
                'budgets': [],
              }
            ],
            'owedToYou': [],
            'youOwe': [],
            'friendCount': 0,
            'pendingRequests': 0,
          });
        }
        if (path == '/api/v1/finance/expenses' && request.method == 'GET') {
          return _json({'content': [], 'page': 0, 'size': 50, 'totalElements': 0, 'totalPages': 0, 'last': true});
        }
        if (path == '/api/v1/finance/expenses' && request.method == 'POST') {
          expensesCreated++;
          return _json({
            'id': 'e$expensesCreated',
            'description': 'Coffee',
            'category': 'FOOD',
            'amount': '100.0000',
            'currency': 'USD',
            'spentOn': '2026-10-12',
            'splitType': 'NONE',
            'paidBy': {'id': 'me', 'username': 'me', 'displayName': 'Me'},
            'createdBy': {'id': 'me', 'username': 'me', 'displayName': 'Me'},
            'shares': [],
            'myShare': '100.0000',
            'myBalance': '0.0000',
            'editable': true,
          }, status: 201);
        }
        if (path == '/api/v1/finance/friends') {
          return _json({
            'me': {'id': 'me', 'username': 'me', 'displayName': 'Me'},
            'friends': [],
            'incoming': [],
            'outgoing': [],
          });
        }
        return _json({'message': 'not found'}, status: 404);
      });
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('loadAll fetches overview, expenses and friends in parallel', () async {
    final backend = _FakeBackend();
    final controller = FinanceController(
      api: FinanceApi(apiClient: ApiClient(baseUrl: 'http://x', httpClient: backend.client)),
    );
    await controller.loadAll();

    expect(controller.status, FinanceLoadStatus.ready);
    expect(controller.me!.id, 'me');
    expect(controller.primaryOverview!.currency, 'INR');
    expect(backend.calls, containsAll(['GET /api/v1/finance/overview', 'GET /api/v1/finance/friends']));
  });

  test('saving an expense refreshes data, remembers currency and notifies Home', () async {
    final backend = _FakeBackend();
    var homeRefreshed = 0;
    final controller = FinanceController(
      api: FinanceApi(apiClient: ApiClient(baseUrl: 'http://x', httpClient: backend.client)),
      onMutated: () async => homeRefreshed++,
    );
    await controller.loadAll();
    await controller.saveExpense(ExpenseDraft(
      description: 'Coffee',
      category: ExpenseCategory.food,
      amount: '100',
      currency: 'USD',
      spentOn: DateTime(2026, 10, 12),
    ));

    expect(homeRefreshed, 1);
    expect(controller.currency, 'USD');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('finance.defaultCurrency'), 'USD');
    expect(controller.overview!.currencies.single.spent.toPlainString(), '100.0000');
  });

  test('a failed load ends in the error state, never a spinner', () async {
    final backend = _FakeBackend()..failOverview = true;
    final controller = FinanceController(
      api: FinanceApi(apiClient: ApiClient(baseUrl: 'http://x', httpClient: backend.client)),
    );
    await controller.loadAll();
    expect(controller.status, FinanceLoadStatus.error);
    expect(controller.errorMessage, isNotNull);
  });

  test('cannot move past the current month', () async {
    final backend = _FakeBackend();
    final controller = FinanceController(
      api: FinanceApi(apiClient: ApiClient(baseUrl: 'http://x', httpClient: backend.client)),
    );
    final start = controller.month;
    await controller.shiftMonth(1);
    expect(controller.month, start);
    await controller.shiftMonth(-1);
    expect(controller.month, DateTime(start.year, start.month - 1));
    expect(controller.isCurrentMonth, isFalse);
  });
}
