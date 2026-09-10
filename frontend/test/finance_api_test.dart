import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exception.dart';
import 'package:frontend/features/finance/finance_api.dart';
import 'package:frontend/features/finance/models.dart';

const String _token = 'jwt-for-tests';

Map<String, dynamic> _requestToJson(http.Request request) =>
    jsonDecode(request.body) as Map<String, dynamic>;

http.Response _jsonResponse(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

ApiClient _clientWith(MockClient mock) =>
    ApiClient(baseUrl: 'http://backend.test', httpClient: mock);

void main() {
  group('FinanceApi accounts', () {
    test('fetchAccounts decodes a list', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/finance/accounts');
        expect(request.headers['authorization'], 'Bearer $_token');
        return _jsonResponse([
          {
            'id': 'a1',
            'name': 'Wallet',
            'type': 'CASH',
            'currency': 'USD',
            'openingBalance': '10.0000',
            'balance': '25.5000',
            'status': 'ACTIVE',
            'notes': null,
          }
        ]);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final FinanceApi api = FinanceApi(apiClient: client);

      final List<Account> accounts = await api.fetchAccounts();

      expect(accounts, hasLength(1));
      final Account account = accounts.single;
      expect(account.name, 'Wallet');
      expect(account.type, AccountType.cash);
      expect(account.currency, 'USD');
      expect(account.openingBalance.toPlainString(), '10.0000');
      expect(account.balance.toPlainString(), '25.5000');
      expect(account.isArchived, isFalse);
    });

    test('createAccount posts normalized payload and parses response',
        () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/finance/accounts');
        final Map<String, dynamic> body = _requestToJson(request);
        expect(body, {
          'name': 'Card',
          'type': 'BANK',
          'currency': 'USD',
          'openingBalance': '100.0000',
        });
        return _jsonResponse({
          'id': 'b9',
          'name': 'Card',
          'type': 'BANK',
          'currency': 'USD',
          'openingBalance': '100.0000',
          'balance': '100.0000',
          'status': 'ACTIVE',
          'notes': null,
        }, status: 201);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final FinanceApi api = FinanceApi(apiClient: client);

      final Account created = await api.createAccount(
        name: 'Card',
        type: AccountType.bank,
        currency: 'usd',
        openingBalance: '100.0000',
      );

      expect(created.id, 'b9');
      expect(created.type, AccountType.bank);
    });
  });

  group('FinanceApi transactions', () {
    test('fetchTransactions sends date query and parses the page', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/finance/transactions');
        expect(request.url.queryParameters['from'], '2026-09-01');
        expect(request.url.queryParameters['to'], '2026-09-30');
        return _jsonResponse({
          'content': [
            {
              'id': 't1',
              'accountId': 'a1',
              'accountName': 'Wallet',
              'accountCurrency': 'USD',
              'categoryId': 'c1',
              'categoryName': 'Groceries',
              'type': 'EXPENSE',
              'amount': '12.3400',
              'currency': 'USD',
              'occurredAt': '2026-09-05T00:00:00Z',
              'createdAt': '2026-09-05T08:00:00Z',
              'description': 'Market',
              'notes': null,
            }
          ],
          'page': 0,
          'size': 50,
          'totalElements': 1,
          'totalPages': 1,
          'last': true,
        });
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final FinanceApi api = FinanceApi(apiClient: client);

      final PageResult<FinanceTransaction> result = await api.fetchTransactions(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );

      expect(result.totalElements, 1);
      expect(result.last, isTrue);
      final FinanceTransaction tx = result.items.single;
      expect(tx.type, TransactionType.expense);
      expect(tx.isIncome, isFalse);
      expect(tx.amount.toPlainString(), '12.3400');
      expect(tx.description, 'Market');
    });

    test('createTransaction serializes occurredAt as date-only', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        final Map<String, dynamic> body = _requestToJson(request);
        expect(body['occurredAt'], '2026-09-15');
        expect(body['amount'], '99.5000');
        expect(body.containsKey('description'), isFalse);
        return _jsonResponse({
          'id': 't2',
          'accountId': 'a1',
          'accountName': 'Wallet',
          'accountCurrency': 'USD',
          'categoryId': 'c1',
          'categoryName': 'Salary',
          'type': 'INCOME',
          'amount': '99.5000',
          'currency': 'USD',
          'occurredAt': '2026-09-15T00:00:00Z',
          'createdAt': '2026-09-15T09:30:00Z',
          'description': null,
          'notes': null,
        }, status: 201);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final FinanceApi api = FinanceApi(apiClient: client);

      final FinanceTransaction created = await api.createTransaction(
        accountId: 'a1',
        categoryId: 'c1',
        type: TransactionType.income,
        amount: '99.5000',
        occurredAt: DateTime(2026, 9, 15),
      );

      expect(created.isIncome, isTrue);
    });
  });

  group('FinanceApi transfers and summary', () {
    test('createTransfer posts source/destination and date-only', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/finance/transfers');
        final Map<String, dynamic> body = _requestToJson(request);
        expect(body['sourceAccountId'], 'a1');
        expect(body['destinationAccountId'], 'a2');
        expect(body['transferredAt'], '2026-09-02');
        expect(body['note'], 'Rent split');
        return _jsonResponse({
          'id': 'f1',
          'sourceAccountId': 'a1',
          'sourceAccountName': 'Wallet',
          'destinationAccountId': 'a2',
          'destinationAccountName': 'Savings',
          'amount': '100.0000',
          'currency': 'USD',
          'transferredAt': '2026-09-02T00:00:00Z',
          'note': 'Rent split',
        }, status: 201);
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final FinanceApi api = FinanceApi(apiClient: client);

      final FinanceTransfer transfer = await api.createTransfer(
        sourceAccountId: 'a1',
        destinationAccountId: 'a2',
        amount: '100.0000',
        transferredAt: DateTime(2026, 9, 2),
        note: 'Rent split',
      );

      expect(transfer.sourceAccountName, 'Wallet');
      expect(transfer.amount.format(currencyCode: transfer.currency),
          'USD 100.0000');
    });

    test('fetchSummary parses multi-currency sections', () async {
      final MockClient mock = MockClient((http.Request request) async {
        expect(request.url.path, '/api/v1/finance/summary');
        return _jsonResponse({
          'from': '2026-09-01',
          'to': '2026-09-30',
          'currencies': [
            {
              'currency': 'USD',
              'income': '5000.0000',
              'expense': '1234.5600',
              'net': '3765.4400',
              'transferIn': '100.0000',
              'transferOut': '50.0000',
              'spendingByCategory': [
                {
                  'categoryId': 'c1',
                  'categoryName': 'Groceries',
                  'amount': '900.0000',
                }
              ],
            }
          ],
        });
      });
      final ApiClient client = _clientWith(mock)..token = _token;
      final FinanceApi api = FinanceApi(apiClient: client);

      final Summary summary = await api.fetchSummary(
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
      );
      final SummaryCurrencySection currency = summary.currencies.single;

      expect(currency.income.toPlainString(), '5000.0000');
      expect(currency.net.toPlainString(), '3765.4400');
      expect(currency.transferIn.toPlainString(), '100.0000');
      expect(currency.spendingByCategory.single.categoryName, 'Groceries');
    });
  });

  group('FinanceApi errors and auth', () {
    test('maps validation errors to fieldErrors', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return _jsonResponse({
          'status': 400,
          'code': 'INVALID_REQUEST',
          'message': 'Validation failed',
          'path': '/api/v1/finance/accounts',
          'errors': [
            {'field': 'currency', 'message': 'must match ^[A-Z]{3}$'}
          ],
        }, status: 400);
      });
      final ApiClient client = _clientWith(mock)..token = _token;

      try {
        await client.post('/api/v1/finance/accounts', body: {});
        fail('expected ApiException');
      } on ApiException catch (error) {
        expect(error.statusCode, 400);
        expect(error.isValidationError, isTrue);
        expect(error.code, 'INVALID_REQUEST');
        expect(error.fieldErrors['currency'], 'must match ^[A-Z]{3}$');
        expect(error.toString(), contains('currency'));
      }
    });

    test('reports unauthorized without leaking state', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return _jsonResponse({
          'status': 401,
          'code': 'AUTHENTICATION_REQUIRED',
          'message': 'Authentication required',
          'path': '/api/v1/finance/accounts',
        }, status: 401);
      });
      final ApiClient client = _clientWith(mock);

      try {
        await client.getList('/api/v1/finance/accounts');
        fail('expected ApiException');
      } on ApiException catch (error) {
        expect(error.isUnauthorized, isTrue);
      }
    });

    test('surfaces network failures as NetworkException', () async {
      final MockClient mock = MockClient((http.Request request) async {
        throw http.ClientException('connection refused');
      });
      final ApiClient client = _clientWith(mock);

      expect(
        () => client.getList('/api/v1/finance/accounts'),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}