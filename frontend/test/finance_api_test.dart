import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/api/api_exception.dart';
import 'package:frontend/core/money/money.dart';
import 'package:frontend/features/finance/finance_api.dart';
import 'package:frontend/features/finance/models.dart';

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> _user(String id, String username) =>
    {'id': id, 'username': username, 'displayName': username[0].toUpperCase() + username.substring(1)};

Map<String, dynamic> expenseJson({String myBalance = '-150.0000'}) => {
      'id': 'e1',
      'description': 'Dinner',
      'category': 'FOOD',
      'amount': '300.0000',
      'currency': 'INR',
      'spentOn': '2026-10-12',
      'notes': null,
      'splitType': 'EQUAL',
      'paidBy': _user('u-bob', 'bob'),
      'createdBy': _user('u-bob', 'bob'),
      'shares': [
        {'user': _user('u-me', 'me'), 'amount': '150.0000', 'value': null},
        {'user': _user('u-bob', 'bob'), 'amount': '150.0000', 'value': null},
      ],
      'myShare': '150.0000',
      'myBalance': myBalance,
      'editable': false,
      'createdAt': '2026-10-12T10:00:00',
    };

void main() {
  group('FinanceApi', () {
    test('createExpense sends the split payload', () async {
      late Map<String, dynamic> sent;
      final api = FinanceApi(
        apiClient: ApiClient(
          baseUrl: 'http://backend.test',
          httpClient: MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/api/v1/finance/expenses');
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(expenseJson(), status: 201);
          }),
        ),
      );

      final expense = await api.createExpense(ExpenseDraft(
        description: ' Dinner ',
        category: ExpenseCategory.food,
        amount: '300',
        currency: 'INR',
        spentOn: DateTime(2026, 10, 12),
        paidBy: 'u-bob',
        splitType: SplitType.percent,
        participants: const [('u-me', '40'), ('u-bob', '60')],
      ));

      expect(sent['description'], 'Dinner');
      expect(sent['category'], 'FOOD');
      expect(sent['spentOn'], '2026-10-12');
      expect(sent['paidBy'], 'u-bob');
      expect(sent['splitType'], 'PERCENT');
      expect(sent['participants'], [
        {'userId': 'u-me', 'value': '40'},
        {'userId': 'u-bob', 'value': '60'},
      ]);
      expect(expense.isShared, isTrue);
      expect(expense.myBalance.isNegative, isTrue);
      expect(expense.myBalance.abs(), Money.parse('150'));
      expect(expense.paidBy.displayName, 'Bob');
    });

    test('personal expense omits participants', () async {
      late Map<String, dynamic> sent;
      final api = FinanceApi(
        apiClient: ApiClient(
          baseUrl: 'http://backend.test',
          httpClient: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return _json(expenseJson(myBalance: '0.0000'), status: 201);
          }),
        ),
      );
      await api.createExpense(ExpenseDraft(
        description: 'Coffee',
        category: ExpenseCategory.food,
        amount: '120',
        currency: 'INR',
        spentOn: DateTime(2026, 10, 12),
      ));
      expect(sent.containsKey('participants'), isFalse);
      expect(sent['splitType'], 'NONE');
    });

    test('friends parses me, balances and requests', () async {
      final api = FinanceApi(
        apiClient: ApiClient(
          baseUrl: 'http://backend.test',
          httpClient: MockClient((request) async => _json({
                'me': _user('u-me', 'me'),
                'friends': [
                  {
                    'user': _user('u-bob', 'bob'),
                    'friend': true,
                    'since': null,
                    'balances': [
                      {'currency': 'INR', 'amount': '-75.5000'}
                    ],
                  }
                ],
                'incoming': [
                  {'id': 'r1', 'user': _user('u-cara', 'cara'), 'createdAt': null}
                ],
                'outgoing': [],
              })),
        ),
      );
      final data = await api.friends();
      expect(data.me!.id, 'u-me');
      expect(data.acceptedFriends.single.balances.single.amount, -Money.parse('75.5'));
      expect(data.incoming.single.user.username, 'cara');
    });

    test('acceptRequest accepts a 204 with no body', () async {
      final api = FinanceApi(
        apiClient: ApiClient(
          baseUrl: 'http://backend.test',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/api/v1/finance/friends/requests/r1/accept');
            return http.Response('', 204);
          }),
        ),
      );
      await api.acceptRequest('r1');
    });

    test('server validation errors surface as ApiException', () async {
      final api = FinanceApi(
        apiClient: ApiClient(
          baseUrl: 'http://backend.test',
          httpClient: MockClient((request) async =>
              _json({'code': 'NOT_FOUND', 'message': 'No user with username @zed'}, status: 404)),
        ),
      );
      await expectLater(api.addFriend('zed'), throwsA(isA<ApiException>()));
    });

    test('overview requests the month and parses budgets', () async {
      final api = FinanceApi(
        apiClient: ApiClient(
          baseUrl: 'http://backend.test',
          httpClient: MockClient((request) async {
            expect(request.url.queryParameters['month'], '2026-03');
            return _json({
              'month': '2026-03',
              'from': '2026-03-01',
              'to': '2026-03-31',
              'currencies': [
                {
                  'currency': 'INR',
                  'spent': '900.0000',
                  'paid': '1200.0000',
                  'previousMonthSpent': '600.0000',
                  'todaySpent': '0.0000',
                  'byCategory': [
                    {'category': 'GROCERIES', 'amount': '900.0000'}
                  ],
                  'daily': [
                    {'date': '2026-03-04', 'amount': '900.0000'}
                  ],
                  'budgets': [
                    {
                      'id': 'b1',
                      'category': null,
                      'currency': 'INR',
                      'monthlyLimit': '600.0000',
                      'spentThisMonth': '900.0000'
                    }
                  ],
                }
              ],
              'owedToYou': [
                {'currency': 'INR', 'amount': '300.0000'}
              ],
              'youOwe': [],
              'friendCount': 2,
              'pendingRequests': 1,
            });
          }),
        ),
      );
      final overview = await api.overview(DateTime(2026, 3));
      final inr = overview.currencies.single;
      expect(inr.byCategory.single.category, ExpenseCategory.groceries);
      expect(inr.overallBudget!.over, isTrue);
      expect(overview.owedToYou.single.display, '₹300');
      expect(overview.pendingRequests, 1);
    });
  });
}
