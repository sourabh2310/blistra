import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/auth/auth_state.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/features/app_scope.dart';
import 'package:frontend/features/dashboard/dashboard_api.dart';
import 'package:frontend/features/dashboard/dashboard_controller.dart';
import 'package:frontend/features/planner/planner_api.dart';
import 'package:frontend/features/planner/planner_controller.dart';
import 'package:frontend/features/planner/screens/home_screen.dart';
import 'package:frontend/features/planner/screens/task_detail_screen.dart';

void main() {
  testWidgets('Planner root has one header, four sections and no duplicate navigation', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/planner/schedule') {
        return http.Response(jsonEncode({'date': '2026-09-24', 'days': 1, 'tasks': [], 'events': []}), 200);
      }
      if (request.url.path == '/api/v1/planner/today') {
        return http.Response(jsonEncode({'overdueTasks': [], 'todayTasks': [], 'todayEvents': []}), 200);
      }
      if (request.url.path == '/api/v1/planner/tasks') {
        return http.Response(jsonEncode({'content': [], 'page': 0, 'size': 50, 'totalElements': 0, 'totalPages': 0, 'last': true}), 200);
      }
      if (request.url.path == '/api/v1/planner/events') {
        return http.Response(jsonEncode({'content': [], 'page': 0, 'size': 50, 'totalElements': 0, 'totalPages': 0, 'last': true}), 200);
      }
      if (request.url.path == '/api/v1/planner/lists') {
        return http.Response('[]', 200);
      }
      return http.Response('{}', 404);
    });
    final apiClient = ApiClient(baseUrl: 'http://localhost:8080', httpClient: client);
    final planner = PlannerController(PlannerApi(apiClient));
    final dashboard = DashboardController(DashboardApi(apiClient));
    final auth = AuthState(apiClient: apiClient);

    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<PlannerController>.value(value: planner)],
        child: AppScope(
          authState: auth,
          dashboard: dashboard,
          planner: planner,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const HomeScreen(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Planner'), findsOneWidget);
    for (final label in ['Today', 'Tasks', 'Lists', 'Events']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.byTooltip('Search Planner'), findsOneWidget);
    expect(find.byTooltip('Choose date'), findsOneWidget);
    expect(find.byTooltip('More Planner actions'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text('No tasks or events scheduled.'), findsOneWidget);

    await tester.tap(find.byTooltip('More Planner actions'));
    await tester.pumpAndSettle();
    expect(find.text('Jump to today'), findsOneWidget);
    expect(find.textContaining('Logout'), findsNothing);
  });

  testWidgets('Task detail displays persisted reminder state and explicit completion', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/planner/tasks/task-1') {
        return http.Response(
          jsonEncode({
            'id': 'task-1',
            'title': 'Finish project report',
            'status': 'TODO',
            'priority': 'MEDIUM',
            'overdue': false,
            'reminderMode': 'AT_START',
            'startAt': '2026-09-24T10:00:00Z',
            'endAt': '2026-09-24T11:30:00Z',
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });
    final apiClient = ApiClient(baseUrl: 'http://localhost:8080', httpClient: client);
    final planner = PlannerController(PlannerApi(apiClient));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: TaskDetailScreen(planner: planner, taskId: 'task-1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Finish project report'), findsOneWidget);
    expect(find.text('Reminder'), findsOneWidget);
    expect(find.text('At start'), findsOneWidget);
    expect(find.text('Complete task'), findsOneWidget);
    expect(find.text('Reopen task'), findsNothing);
  });
}
