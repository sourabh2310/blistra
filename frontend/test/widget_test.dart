import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/main.dart';
import 'package:frontend/core/api/api_config.dart';
import 'package:frontend/core/api/auth_repository.dart';
import 'package:frontend/features/documents/repositories/documents_repository.dart';
import 'package:frontend/features/documents/providers/documents_provider.dart';
import 'package:frontend/features/documents/models/document.dart';

@GenerateMocks([ApiConfig, AuthRepository, DocumentsRepository])
import 'widget_test.mocks.dart';

void main() {
  group('Blistra App', () {
    late MockApiConfig mockApiConfig;
    late MockAuthRepository mockAuthRepository;
    late MockDocumentsRepository mockDocumentsRepository;

    setUp(() {
      mockApiConfig = MockApiConfig();
      mockAuthRepository = MockAuthRepository();
      mockDocumentsRepository = MockDocumentsRepository();

      when(mockApiConfig.isAuthenticated).thenReturn(false);
      when(mockApiConfig.baseUrl).thenReturn('http://10.0.2.2:8080/api/v1');
      when(mockApiConfig.token).thenReturn(null);
    });

    Widget buildTestApp() {
      return MultiProvider(
        providers: [
          Provider<ApiConfig>.value(value: mockApiConfig),
          Provider<AuthRepository>.value(value: mockAuthRepository),
          Provider<DocumentsRepository>.value(value: mockDocumentsRepository),
          ChangeNotifierProvider<DocumentsProvider>(
            create: (_) => DocumentsProvider(mockDocumentsRepository),
          ),
        ],
        child: const BlistraApp(
          apiConfig: null,
          authRepository: null,
          documentsRepository: null,
        ),
      );
    }

    testWidgets('Shows login page when unauthenticated', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.text('Blistra Documents'), findsOneWidget);
      expect(find.text('Your private document vault'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });

    testWidgets('Login form validation works', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('Toggle to register mode shows create account button', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestApp());
      await tester.pump();

      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });
  });

  group('DocumentsProvider', () {
    late MockDocumentsRepository mockRepo;
    late DocumentsProvider provider;

    setUp(() {
      mockRepo = MockDocumentsRepository();
      provider = DocumentsProvider(mockRepo);
    });

    test('Initial state is empty', () {
      expect(provider.documents, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('Load sets loading state', () async {
      when(mockRepo.list(page: 0, size: 20, category: null, from: null, to: null))
          .thenAnswer((_) async => DocumentPage(
                content: [],
                page: 0,
                size: 20,
                totalElements: 0,
                totalPages: 0,
              ));

      final future = provider.load();
      expect(provider.isLoading, isTrue);
      await future;
      expect(provider.isLoading, isFalse);
    });
  });
}