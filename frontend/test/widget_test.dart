import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('Blistra app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const BlistraApp());

    expect(find.text('Blistra'), findsOneWidget);
    expect(
      find.text('Everything you need. One app.'),
      findsOneWidget,
    );
  });
}