/// Blistra app entry point with auth gating and dependency injection.
library;

import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/api/api_config.dart';
import 'core/auth/auth_state.dart';
import 'dashboard/dashboard_api.dart';
import 'dashboard/dashboard_controller.dart';
import 'dashboard/screens/dashboard_screen.dart';
import 'features/app_scope.dart';
import 'features/auth/login_page.dart';
import 'planner/planner_api.dart';
import 'planner/planner_controller.dart';

void main() {
  final apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  final authState = AuthState(apiClient: apiClient);
  final authController = AuthController(authState: authState);
  final plannerController = PlannerController(
    PlannerApi(apiClient),
  );
  final dashboardController = DashboardController(
    DashboardApi(apiClient: apiClient),
  );

  runApp(
    AppScope(
      apiClient: apiClient,
      authState: authState,
      auth: authController,
      planner: plannerController,
      dashboard: dashboardController,
      child: const BlistraApp(),
    ),
  );
}

class BlistraApp extends StatelessWidget {
  const BlistraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blistra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authController = AppScope.of(context).auth;

    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        switch (authController.status) {
          case AuthStatus.authenticated:
            return const DashboardScreen();
          case AuthStatus.unauthenticated:
            return const LoginPage();
          case AuthStatus.unknown:
          case AuthStatus.busy:
            return const _LoadingScaffold();
        }
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}