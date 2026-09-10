import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notifications/app_dependencies.dart';
import 'notifications/screens/auth_screen.dart';
import 'notifications/screens/home_shell.dart';
import 'notifications/state/auth_controller.dart';
import 'notifications/state/reminders_controller.dart';
import 'notifications/state/settings_controller.dart';

/// Allows tests to inject real-but-fake controllers while production runs the
/// default wiring.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SharedPreferences must be initialized before we can read the stored token.
  final prefs = await SharedPreferences.getInstance();

  // API base URL can be overridden at build time: --dart-define=API_BASE_URL=...
  // Defaults to the Android emulator's loopback alias for the host machine.
  const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  // Initialize the notification scheduler early so scheduled reminders fire
  // even if the app is cold-started from a notification tap.
  try {
    final scheduler = FlutterNotificationScheduler();
    await scheduler.initialize();
    await scheduler.requestPermissions();
  } catch (error) {
    // If the scheduler fails (e.g., missing permissions on some devices),
    // we log and continue — the app remains usable, just without local
    // notifications until the issue is resolved.
    // ignore: avoid_print
    print('Notification scheduler init failed: $error');
  }

  final deps = AppDependencies(baseUrl: apiBaseUrl, prefs: prefs);

  runApp(BlistraApp(
    authController: deps.authController,
    remindersController: deps.remindersController,
    settingsController: deps.settingsController,
  ));
}

class BlistraApp extends StatelessWidget {
  const BlistraApp({
    super.key,
    required this.authController,
    required this.remindersController,
    required this.settingsController,
  });

  final AuthController authController;
  final RemindersController remindersController;
  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blistra',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF386641)),
      ),
      home: AuthGate(
        authController: authController,
        remindersController: remindersController,
        settingsController: settingsController,
      ),
    );
  }
}

/// Routes to the login screen or the app shell based on auth state.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.authController,
    required this.remindersController,
    required this.settingsController,
  });

  final AuthController authController;
  final RemindersController remindersController;
  final SettingsController settingsController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authController,
      builder: (context, _) {
        if (authController.isAuthenticated) {
          return HomeShell(
            authController: authController,
            remindersController: remindersController,
            settingsController: settingsController,
          );
        }
        return const AuthScreen();
      },
    );
  }
}