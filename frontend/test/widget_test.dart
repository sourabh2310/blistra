import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';
import 'package:frontend/auth/auth_controller.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/auth_token.dart';
import 'package:frontend/core/session.dart';
import 'package:frontend/planner/planner_api.dart';
import 'package:frontend/planner/planner_controller.dart';

void main() {
  testWidgets('Blistra app loads', (WidgetTester tester) async {
    // Use a lightweight in-memory AuthController that stays unauthenticated
    // so the login screen renders and we can assert on it.
    final authToken = AuthToken();
    final apiClient = ApiClient(tokenProvider: () => authToken.value);
    final auth = AuthController(
      apiClient: apiClient,
      sessionStore: _InMemorySessionStore(),
      authToken: authToken,
    );
    final planner = PlannerController(PlannerApi(apiClient));

    await tester.pumpWidget(
      BlistraApp(authController: auth, plannerController: planner),
    );

    expect(find.text('Blistra'), findsOneWidget);
    expect(find.text('Everything you need. One app.'), findsNothing);
    // Login screen should show the email field
    expect(find.byType(TextFormField), findsAtLeastNWidgets(1));
  });
}

class _InMemorySessionStore extends SessionStore {
  String? _token;
  @override
  Future<String?> readToken() async => _token;
  @override
  Future<void> writeToken(String token) async => _token = token;
  @override
  Future<void> clear() async => _token = null;
}