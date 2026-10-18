import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'dart:convert';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/features/ai/ai_api.dart';
import 'package:frontend/features/ai/ai_screen.dart';

class TestAuthState extends AuthState {
  TestAuthState(ApiClient client) : super(apiClient: client);
  bool signedIn = true;
  @override
  bool get isAuthenticated => signedIn;
  @override
  String get userEmail => 'user@example.com';
  void expire() {
    signedIn = false;
    notifyListeners();
  }
}

void main() {
  testWidgets('Ending the session closes chat and removes its messages', (
    tester,
  ) async {
    final client = ApiClient(
      baseUrl: 'http://localhost',
      httpClient: MockClient(
        (_) async => http.Response('{"reply":"Private daily summary"}', 200),
      ),
    );
    final auth = TestAuthState(client);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AiScreen(api: AiApi(client), authState: auth),
                ),
              ),
              child: const Text('Open AI'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open AI'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Help');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Private daily summary'), findsOneWidget);
    auth.expire();
    await tester.pumpAndSettle();
    expect(find.byType(AiScreen), findsNothing);
    expect(find.text('Private daily summary'), findsNothing);
  });

  testWidgets('Chat fits a small display with its keyboard open', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: AiScreen(api: AiApi(ApiClient(baseUrl: 'http://localhost'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
  });
  testWidgets('Sharing defaults off; sends a message and displays the reply', (
    tester,
  ) async {
    final requests = <Map<String, dynamic>>[];
    final api = AiApi(
      ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient((request) async {
          requests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            '{"reply":"Open Planner to organize your tasks."}',
            200,
          );
        }),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: AiScreen(api: api)));
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
    await tester.tap(find.text('What can I do in Blistra?'));
    await tester.pumpAndSettle();
    expect(requests.single['includeSummary'], false);
    expect(requests.single['history'], isEmpty);
    expect(find.text('Open Planner to organize your tasks.'), findsOneWidget);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(find.text('Open Planner to organize your tasks.'), findsNothing);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      true,
    );
    await tester.tap(find.byTooltip('Clear chat'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      false,
    );
  });

  testWidgets('Provider failure preserves draft for retry', (tester) async {
    final api = AiApi(
      ApiClient(
        baseUrl: 'http://localhost',
        httpClient: MockClient(
          (_) async => http.Response(
            '{"code":"AI_UNAVAILABLE","message":"Blistra AI is unavailable."}',
            503,
          ),
        ),
      ),
    );
    await tester.pumpWidget(MaterialApp(home: AiScreen(api: api)));
    await tester.enterText(find.byType(TextField), 'Help me plan my day');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(find.text('Blistra AI is unavailable.'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Help me plan my day',
    );
  });
}
