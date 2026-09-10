import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Blistra renders an auth screen before signing in',
      (WidgetTester tester) async {
    await tester.pumpWidget(const BlistraApp());

    expect(find.text('Blistra'), findsOneWidget);
    expect(find.text('Sign in to your money tracker'), findsOneWidget);
  });
}