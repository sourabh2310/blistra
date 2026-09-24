/// Home shell regression tests: header wiring, single Add, Hub reachability.
///
/// Home never owns a floating Add button (the global bottom-navigation Add
/// is the only one), the header actions fire real callbacks, and Hub stays
/// reachable when unpinned.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/app/app_scope.dart';
import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/core/auth/auth_storage.dart';
import 'package:frontend/features/dashboard/dashboard_api.dart';
import 'package:frontend/features/dashboard/dashboard_controller.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart';
import 'package:frontend/features/planner/planner_api.dart';
import 'package:frontend/features/planner/planner_controller.dart';

Widget _home({
  void Function(String destinationId)? onDestination,
  VoidCallback? onSearch,
  VoidCallback? onNotifications,
  VoidCallback? onProfile,
  VoidCallback? onCustomizeHome,
  bool hubPinned = true,
}) {
  final mock = MockClient((req) async => http.Response('{}', 200));
  final api = ApiClient(baseUrl: 'http://localhost', httpClient: mock);
  return AppScope(
    authState: AuthState(apiClient: api, storage: AuthStorage()),
    dashboard: DashboardController(api: DashboardApi(apiClient: api)),
    planner: PlannerController(PlannerApi(api)),
    child: MaterialApp(
      home: DashboardScreen(
        onDestination: onDestination,
        onSearch: onSearch,
        onNotifications: onNotifications,
        onProfile: onProfile,
        onCustomizeHome: onCustomizeHome,
        hubPinned: hubPinned,
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('no duplicate floating Add on Home', (tester) async {
    await tester.pumpWidget(_home());
    await tester.pump();
    // The only global Add lives in the bottom navigation (owned by the
    // shell, not Home).
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('header search opens Search', (tester) async {
    var searches = 0;
    await tester.pumpWidget(_home(onSearch: () => searches++));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    expect(searches, 1);
  });

  testWidgets('header bell opens Notifications', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_home(onNotifications: () => opened++));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.notifications_none_outlined));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('avatar opens Profile', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_home(onProfile: () => opened++));
    await tester.pump();
    // Avatar carries an explicit Profile semantic.
    await tester.tap(find.bySemanticsLabel('Profile'));
    await tester.pump();
    expect(opened, 1);
  });

  testWidgets('module cards navigate to owning domains', (tester) async {
    String? destination;
    await tester.pumpWidget(
        _home(onDestination: (id) => destination = id));
    await tester.pump();
    await tester.tap(find.text('Health').first);
    await tester.pump();
    expect(destination, 'HEALTH');
  });

  testWidgets('Hub entry appears only when Hub is unpinned',
      (tester) async {
    await tester.pumpWidget(_home(hubPinned: false));
    await tester.pump();
    expect(find.text('Explore Hub'), findsOneWidget);

    await tester.pumpWidget(_home(hubPinned: true));
    await tester.pump();
    expect(find.text('Explore Hub'), findsNothing);
  });

  testWidgets('Customize shortcut is available', (tester) async {
    var customized = 0;
    await tester.pumpWidget(
        _home(onCustomizeHome: () => customized++));
    await tester.pump();
    await tester.tap(find.text('Customize'));
    await tester.pump();
    expect(customized, 1);
  });

  testWidgets('no fake notification badge without data', (tester) async {
    await tester.pumpWidget(_home());
    await tester.pump();
    // Real scheduled reminders would set the dot; with none loaded there
    // must be no red badge.
    expect(find.byType(CircleAvatar), findsNothing);
  });
}
