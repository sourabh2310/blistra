/// Renders every module screen inside the signed-in app shell, backed by a
/// fake API, and fails on any exception (layout overflow, unbounded
/// constraints, missing providers). Finance gets realistic data so its
/// populated states are exercised too.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app.dart';
import 'package:frontend/app/app_dependencies.dart';
import 'package:frontend/app/app_shell.dart';
import 'package:frontend/features/finance/screens/expense_form_screen.dart';

Map<String, dynamic> _user(String id, String name) =>
    {'id': id, 'username': name.toLowerCase(), 'displayName': name};

final _expense = {
  'id': 'e1',
  'description': 'Team dinner',
  'category': 'FOOD',
  'amount': '1200.0000',
  'currency': 'INR',
  'spentOn': DateTime.now().toIso8601String().substring(0, 10),
  'notes': 'Birthday',
  'splitType': 'EQUAL',
  'paidBy': _user('me', 'Me'),
  'createdBy': _user('me', 'Me'),
  'shares': [
    {'user': _user('me', 'Me'), 'amount': '600.0000'},
    {'user': _user('bob', 'Bob'), 'amount': '600.0000'},
  ],
  'myShare': '600.0000',
  'myBalance': '600.0000',
  'editable': true,
};

http.Response _respond(http.Request request) {
  final path = request.url.path;
  Object body;
  if (path == '/api/v1/finance/overview') {
    body = {
      'from': '2026-10-01',
      'currencies': [
        {
          'currency': 'INR',
          'spent': '600.0000',
          'paid': '1200.0000',
          'previousMonthSpent': '400.0000',
          'todaySpent': '600.0000',
          'byCategory': [
            {'category': 'FOOD', 'amount': '600.0000'}
          ],
          'daily': [
            {'date': _expense['spentOn'], 'amount': '600.0000'}
          ],
          'budgets': [
            {'id': 'b1', 'category': null, 'currency': 'INR', 'monthlyLimit': '500.0000', 'spentThisMonth': '600.0000'}
          ],
        }
      ],
      'owedToYou': [
        {'currency': 'INR', 'amount': '600.0000'}
      ],
      'youOwe': [],
      'friendCount': 1,
      'pendingRequests': 1,
    };
  } else if (path == '/api/v1/finance/expenses') {
    body = {'content': [_expense], 'page': 0, 'size': 50, 'totalElements': 1, 'totalPages': 1, 'last': true};
  } else if (path == '/api/v1/finance/friends') {
    body = {
      'me': _user('me', 'Me'),
      'friends': [
        {
          'user': _user('bob', 'Bob'),
          'friend': true,
          'balances': [
            {'currency': 'INR', 'amount': '600.0000'}
          ]
        },
        {'user': _user('dee', 'Dee'), 'friend': true, 'balances': []},
      ],
      'incoming': [
        {'id': 'r1', 'user': _user('cara', 'Cara')}
      ],
      'outgoing': [
        {'id': 'r2', 'user': _user('eve', 'Eve')}
      ],
    };
  } else {
    // Everything else: unavailable, so screens render their error states.
    return http.Response(jsonEncode({'code': 'UNAVAILABLE', 'message': 'Not in this test'}), 503,
        headers: {'content-type': 'application/json'});
  }
  return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});
}

Future<AppDependencies> _signedIn(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({'auth_token': 'token', 'auth_email': 'me@example.test'});
  final deps = (await tester.runAsync(() => AppDependencies.create(
        baseUrl: 'http://backend.test',
        httpClient: MockClient((r) async => _respond(r)),
      )))!;
  return deps;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('every shell destination renders without exceptions', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final deps = await _signedIn(tester);
    await tester.pumpWidget(BlistraApp(deps: deps));
    await _settle(tester);
    expect(find.byType(AppShell), findsOneWidget);

    final dynamic shell = tester.state(find.byType(AppShell));
    for (final id in ['HOME', 'PLANNER', 'HEALTH', 'MEDICINES', 'DIET', 'HABITS', 'FINANCE', 'HUB', 'DOCUMENTS']) {
      shell.goToDestination(id);
      await _settle(tester);
      expect(tester.takeException(), isNull, reason: '$id threw while rendering');
      final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
      navigator.popUntil((route) => route.isFirst);
      await _settle(tester);
    }
  });

  testWidgets('Finance tabs, expense form and split section render with data', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final deps = await _signedIn(tester);
    await tester.pumpWidget(BlistraApp(deps: deps));
    await _settle(tester);
    final dynamic shell = tester.state(find.byType(AppShell));
    shell.goToDestination('FINANCE');
    await _settle(tester);

    expect(find.text('Team dinner', skipOffstage: false), findsWidgets);
    expect(find.textContaining('Friends (1)'), findsOneWidget);

    await tester.tap(find.textContaining('Friends (1)'));
    await _settle(tester);
    expect(find.text('Add'), findsWidgets);
    expect(find.text('Cara'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Expenses'));
    await _settle(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('finance-add-expense')));
    await _settle(tester);
    expect(find.byType(ExpenseFormScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Split with friends'), 200,
        scrollable: find.descendant(of: find.byType(ExpenseFormScreen), matching: find.byType(Scrollable)).first);
    await tester.tap(find.text('Split with friends'));
    await _settle(tester);
    expect(find.text('Choose friends'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
