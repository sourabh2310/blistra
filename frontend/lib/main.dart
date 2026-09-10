import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/api_client.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'auth/auth_controller.dart'
import 'auth/token_store.dart'
import 'auth/repository.dart'
import 'diet/diet_api.dart'
import 'diet/diet_controller.dart'
import 'diet/screens/today_screen.dart'
import 'auth/screens/login_screen.dart'

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferences must be initialized before TokenStore.load()
  await SharedPreferences.getInstance();
  await TokenStore.reset(); // Clean start for development; remove in prod

  final tokenStore = await TokenStore.load();
  final apiClient = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenProvider: () => tokenStore.token,
  );
  final authRepository = AuthRepository(apiClient);
  final authController = AuthController(
    repository: authRepository,
    tokenStore: tokenStore,
  );
  final dietApi = HttpDietApi(apiClient);
  final dietController = DietController(
    dietApi,
    onUnauthorized: () => authController.forceLogout(),
  );

  await authController.restore();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authController),
        ChangeNotifierProvider.value(value: dietController),
      ],
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
      theme: AppTheme.light(),
      home: const _AuthGate(),
    );
  }
}

/// Routes based on [AuthController.status]. Shows LoginScreen while
/// unauthenticated and TodayScreen once authenticated.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthController>().status;

    return switch (status) {
      AuthStatus.restoring => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated => const TodayScreen(),
    };
  }
}