import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/money/money.dart';
import 'package:frontend/features/finance/finance_api.dart';
import 'package:frontend/features/finance/finance_controller.dart';
import 'package:frontend/features/finance/models.dart';
import 'package:frontend/features/finance/screens/groups_tab.dart';
import 'package:frontend/features/finance/screens/payment_tile.dart';
import 'package:frontend/features/finance/widgets/finance_widgets.dart';

void main() {
  test('finance entry preserves four-decimal payments and rejects malformed amounts', () {
    expect(normalizeAmount('0.0001'), '0.0001');
    expect(normalizeAmount('.5'), '0.5');
    expect(normalizeAmount('0'), isNull);
    expect(normalizeAmount('1.00001'), isNull);
    expect(normalizeAmount('NaN'), isNull);
    expect(normalizeAmount('-1'), isNull);
  });
  const group = TripGroup(
    id: 'trip',
    name: 'Goa trip',
    currency: 'INR',
    ownerId: 'alice',
    membership: 'ACCEPTED',
  );
  testWidgets(
    'an invitation requires an explicit join and does not open the ledger',
    (tester) async {
      var joined = false;
      final api = ApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((r) async {
          if (r.method == 'POST') {
            expect(r.url.path, endsWith('/accept'));
            joined = true;
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode([
              {
                'id': 'trip',
                'name': 'Goa trip',
                'currency': 'INR',
                'ownerId': 'alice',
                'membership': joined ? 'ACCEPTED' : 'INVITED',
              },
            ]),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => FinanceController(api: FinanceApi(apiClient: api)),
          child: const MaterialApp(home: Scaffold(body: GroupsTab())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('INR · Invitation'), findsOneWidget);
      expect(find.text('Group balances'), findsNothing);
      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(joined, isTrue);
      expect(find.text('INR · Joined'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'group screen displays three people and separate currencies without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final client = ApiClient(
        baseUrl: 'http://test',
        httpClient: MockClient((r) async {
          Object body = [];
          if (r.url.path.endsWith('/groups/trip')) {
            body = {
              'group': {
                'id': 'trip',
                'name': 'Goa trip',
                'currency': 'INR',
                'ownerId': 'alice',
                'membership': 'ACCEPTED',
              },
              'members': [
                for (final name in ['alice', 'bob', 'carol'])
                  {
                    'user': {'id': name, 'username': name, 'displayName': name},
                    'status': 'ACCEPTED',
                    'owner': name == 'alice',
                  },
              ],
              'balances': [
                {'userId': 'alice', 'currency': 'INR', 'amount': '200.0000'},
                {'userId': 'bob', 'currency': 'INR', 'amount': '-100.0000'},
                {'userId': 'carol', 'currency': 'USD', 'amount': '-0.0001'},
              ],
            };
          } else if (r.url.path.endsWith('/expenses')) {
            body = {
              'content': [],
              'last': true,
              'page': 0,
              'size': 50,
              'totalElements': 0,
              'totalPages': 0,
            };
          }
          return http.Response(jsonEncode(body), 200);
        }),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => FinanceController(api: FinanceApi(apiClient: client)),
          child: const MaterialApp(home: GroupDetailScreen(group: group)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('GROUP BALANCES'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(find.textContaining('0.0001'), findsOneWidget);
      expect(find.text('bob'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'pending payment requires confirmation and asks before deciding',
    (tester) async {
      bool? decision;
      final payment = Settlement(
        id: 'p',
        payer: const UserSummary(
          id: 'a',
          username: 'alice',
          displayName: 'Alice',
        ),
        payee: const UserSummary(id: 'b', username: 'bob', displayName: 'Bob'),
        amount: Money.parse('100'),
        currency: 'INR',
        settledOn: DateTime(2026, 10, 17),
        editable: false,
        status: 'PENDING',
        confirmable: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaymentTile(
              settlement: payment,
              onDecision: (value) => decision = value,
            ),
          ),
        ),
      );
      expect(find.textContaining('Balance unchanged'), findsOneWidget);
      await tester.tap(find.text('Confirm payment'));
      await tester.pumpAndSettle();
      expect(decision, isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(decision, isTrue);
    },
  );
}
