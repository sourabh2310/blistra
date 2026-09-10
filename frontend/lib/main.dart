import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api/api_config.dart';
import 'core/api/auth_repository.dart'
import 'features/auth/login_page.dart'
import 'features/documents/documents_page.dart'
import 'features/documents/providers/documents_provider.dart'
import 'features/documents/repositories/documents_repository.dart'

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance()
  final apiConfig = ApiConfig()
  await apiConfig.init()

  runApp(BlistraApp(
    apiConfig: apiConfig,
    authRepository: AuthRepository(apiConfig),
    documentsRepository: DocumentsRepository(apiConfig),
  ))
}

class BlistraApp extends StatelessWidget {
  final ApiConfig apiConfig
  final AuthRepository authRepository
  final DocumentsRepository documentsRepository

  const BlistraApp({
    super.key,
    required this.apiConfig,
    required this.authRepository,
    required this.documentsRepository,
  })

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiConfig>.value(value: apiConfig),
        Provider<AuthRepository>.value(value: authRepository),
        Provider<DocumentsRepository>.value(value: documentsRepository),
        ChangeNotifierProxyProvider<ApiConfig, DocumentsProvider>(
          create: (_) => DocumentsProvider(documentsRepository),
          update: (_, api, previous) =>
              previous ?? DocumentsProvider(documentsRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Blistra',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        ),
        themeMode: ThemeMode.system,
        home: const AuthGate(),
      ),
    )
  }
}

/// Gate that shows login or documents based on auth state
class AuthGate extends StatelessWidget {
  const AuthGate({super.key})

  @override
  Widget build(BuildContext context) {
    return Consumer<ApiConfig>(
      builder: (context, api, _) {
        if (api.isAuthenticated) {
          return const DocumentsPage()
        }
        return const LoginPage()
      },
    )
  }
}