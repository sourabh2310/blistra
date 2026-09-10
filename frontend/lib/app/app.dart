/// Application root: theme, auth gate, shell.
library;

import 'package:flutter/material.dart';

import '../core/auth/auth_state.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_screen.dart';
import 'app_dependencies.dart';
import 'app_shell.dart';

class BlistraApp extends StatelessWidget {
  const BlistraApp({super.key, required this.deps});

  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Blistra',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: AuthGate(deps: deps),
    );
  }
}

/// Routes to login or the shell based on [AuthState].
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.deps});

  final AppDependencies deps;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.authState,
      builder: (context, _) {
        if (deps.authState.status == AuthStatus.unknown ||
            deps.authState.status == AuthStatus.busy) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (deps.authState.isAuthenticated) {
          return AppShell(deps: deps);
        }
        return AuthScreen(deps: deps);
      },
    );
  }
}
