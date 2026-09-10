import 'package:flutter/material.dart';

import 'core/api/api_client.dart';
import 'core/auth/auth_state.dart';
import 'features/auth/auth_screen.dart';
import 'features/finance/finance_controller.dart'
import 'features/finance/finance_home.dart'
import 'features/finance/finance_api.dart'
import 'features/finance/finance_scope.dart'

/// Default backend URL. Override with
/// `--dart-define=API_BASE_URL=http://192.168.x.x:8080`.
const String _defaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);

void main() {
  runApp(BlistraApp(apiClient: ApiClient(baseUrl: _defaultBaseUrl)));
}

/// Blistra app root.
///
/// Dependencies can be injected for tests; the production default is the real
/// backend client.
class BlistraApp extends StatefulWidget {
  const BlistraApp({super.key, this.apiClient});

  final ApiClient? apiClient;

  @override
  State<BlistraApp> createState() => _BlistraAppState();
}

class _BlistraAppState extends State<BlistraApp> {
  late final ApiClient _apiClient;
  late final AuthState _auth;
  late final FinanceController _finance;

  @override
  void initState() {
    super.initState();
    _apiClient = widget.apiClient ?? ApiClient(baseUrl: _defaultBaseUrl);
    _auth = AuthState(apiClient: _apiClient);
    _finance = FinanceController(api: FinanceApi(apiClient: _apiClient));
  }

  @override
  void dispose() {
    _finance.dispose();
    _auth.dispose();
    _apiClient.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      auth: _auth,
      child: FinanceScope(
        controller: _finance,
        child: MaterialApp(
          title: 'Blistra',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(useMaterial3: true),
          home: const RootGate(),
        ),
      ),
    );
  }
}

/// Switches between the auth flow and the finance home based on the session.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthState auth = AuthScope.of(context);
    if (auth.isAuthenticated) {
      return const FinanceHome();
    }
    return const AuthScreen();
  }
}