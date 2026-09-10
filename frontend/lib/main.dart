import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_screens.dart';
import 'core/api_client.dart'
import 'core/auth_token.dart'
import 'core/session.dart'
import 'planner/planner_api.dart'
import 'planner/planner_controller.dart'
import 'planner/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final authToken = AuthToken();
  final apiClient = ApiClient(tokenProvider: () => authToken.value);
  final auth = AuthController(
    apiClient: apiClient,
    sessionStore: SessionStore(),
    authToken: authToken,
  );
  final planner = PlannerController(PlannerApi(apiClient));

  runApp(BlistraApp(authController: auth, plannerController: planner));
}

class BlistraApp extends StatelessWidget {
  const BlistraApp({super.key, required this.authController, required this.plannerController});

  final AuthController authController;
  final PlannerController plannerController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blistra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF386641)),
      ),
      home: AppScope(
        auth: authController,
        planner: plannerController,
        child: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    final scope = AppScope.of(context);
    if (scope.auth.status == AuthStatus.unknown) {
      scope.auth.restore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final auth = scope.auth;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          case AuthStatus.authenticated:
            return const HomeScreen();
          case AuthStatus.unauthenticated:
            return LoginScreen(auth: auth);
        }
      },
    );
  }
}