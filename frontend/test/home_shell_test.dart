/// Home shell regression tests: header wiring, single Add, Hub reachability.
///
/// Home never owns a floating Add button (the global bottom-navigation Add
/// is the only one), the header actions fire real callbacks, and Hub stays
/// reachable when unpinned.
library;

import 'dart:convert';

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
  bool hubPinned = true,
  DashboardController? controller,
  List<String>? homeWidgets,
}) {
  final mock = MockClient((req) async => http.Response('{}', 200));
  final api = ApiClient(baseUrl: 'http://localhost', httpClient: mock);
  final dashboard = controller ??
      DashboardController(api: DashboardApi(apiClient: api));
  return AppScope(
    authState: AuthState(apiClient: api, storage: AuthStorage()),
    dashboard: dashboard,
    planner: PlannerController(PlannerApi(api)),
    child: MaterialApp(
      home: DashboardScreen(
        onDestination: onDestination,
        onSearch: onSearch,
        onNotifications: onNotifications,
        onProfile: onProfile,
        hubPinned: hubPinned,
        homeWidgets: homeWidgets,
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
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'date': '2026-09-24',
            'generatedAt': '2026-09-24T08:00:00+05:30',
            'health': {
              'latestMeasurements': [
                {'type': 'WEIGHT', 'value': '68.4', 'unit': 'kg'},
              ],
              'upcomingAppointments': [],
              'unavailable': false,
            },
          }),
          200,
        ));
    final api = ApiClient(baseUrl: 'http://localhost', httpClient: mock);
    final controller = DashboardController(api: DashboardApi(apiClient: api));
    await controller.loadDashboard(date: DateTime(2026, 9, 24));
    String? destination;
    await tester.pumpWidget(_home(
      controller: controller,
      homeWidgets: const ['YOUR_LIFE', 'HEALTH'],
      onDestination: (id) => destination = id,
    ));
    await tester.pump();
    await tester.tap(find.text('Health'));
    expect(destination, 'HEALTH');
  });

  testWidgets('Home reflows on small and large phone widths', (tester) async {
    final mock = MockClient((req) async => http.Response(
          jsonEncode({
            'date': '2026-09-24',
            'generatedAt': '2026-09-24T08:00:00+05:30',
            'user': {
              'displayName': 'Sourabhkumar Chandrasekhar',
              'firstName': 'Sourabhkumar Chandrasekhar',
            },
            'planner': {
              'overdueTasks': [],
              'todayTasks': [],
              'todayEvents': [],
              'unavailable': false,
            },
          }),
          200,
        ));
    final api = ApiClient(baseUrl: 'http://localhost', httpClient: mock);
    final controller = DashboardController(api: DashboardApi(apiClient: api));
    await controller.loadDashboard(date: DateTime(2026, 9, 24));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(320, 640), const Size(412, 915)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_home(
        controller: controller,
        homeWidgets: const [
          'TODAY_OVERVIEW',
          'TODAYS_SCHEDULE',
          'NEEDS_ATTENTION',
          'YOUR_LIFE',
          'THIS_WEEK',
          'HEALTH',
          'MEDICINES',
          'DIET',
          'HABITS',
          'FINANCE',
        ],
      ));
      await tester.pump();
      expect(find.text('Sourabhkumar Chandrasekhar'), findsOneWidget);
      expect(find.text('Today overview'), findsOneWidget);
      expect(find.text("Today's schedule"), findsOneWidget);
      expect(find.text('Needs your attention'), findsOneWidget);
      expect(find.text('Your life'), findsOneWidget);
      expect(find.byTooltip('Planner'), findsNothing);
      expect(tester.takeException(), isNull);
    }
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

  testWidgets('Home has no permanent Customize action', (tester) async {
    await tester.pumpWidget(_home());
    await tester.pump();
    expect(find.text('Customize'), findsNothing);
  });

  testWidgets('no fake notification badge without data', (tester) async {
    await tester.pumpWidget(_home());
    await tester.pump();
    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
     expect(find.byType(CircleAvatar), findsOneWidget);
     expect(
       find.byWidgetPredicate(
         (widget) => widget is CircleAvatar && widget.radius == 5,
       ),
       findsNothing,
     );
  });
}
