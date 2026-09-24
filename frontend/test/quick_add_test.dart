/// Focused Quick Add tests: action set, premium surface, dismissal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/widgets/quick_add.dart';

void main() {
  group('quickAddActions', () {
    test('exposes the eight real creation flows', () {
      final actions = quickAddActions;
      expect(actions, hasLength(8));
      expect(
        actions.map((a) => a.label).toList(),
        [
          'Task',
          'Event',
          'Meal',
          'Medicine',
          'Habit',
          'Health',
          'Expense',
          'Water',
        ],
      );
      expect(
        actions.map((a) => a.kind).toSet(),
        hasLength(8),
      );
    });

    test('Task/Event are primary (first two)', () {
      final actions = quickAddActions;
      expect(actions[0].kind, QuickAddKind.task);
      expect(actions[1].kind, QuickAddKind.event);
    });

    test('descriptions match actual functionality', () {
      final byKind = {for (final a in quickAddActions) a.kind: a};
      expect(byKind[QuickAddKind.task]!.description, 'To do, work, personal');
      expect(
        byKind[QuickAddKind.event]!.description,
        'Meeting, appointment',
      );
      expect(
        byKind[QuickAddKind.medicine]!.description,
        'Take a dose, log medicine',
      );
      expect(
        byKind[QuickAddKind.meal]!.description,
        'Breakfast, lunch, dinner, snack',
      );
      expect(
        byKind[QuickAddKind.water]!.description,
        'Log water intake',
      );
      expect(byKind[QuickAddKind.habit]!.description, 'Track your habits');
      expect(
        byKind[QuickAddKind.health]!.description,
        'Weight, BP, measurements',
      );
      expect(byKind[QuickAddKind.expense]!.description, 'Track your spending');
    });

    test('every action has an accessible semantic label', () {
      for (final a in quickAddActions) {
        expect(a.semanticLabel.toLowerCase(), contains('add'));
      }
      final labels = quickAddActions.map((a) => a.semanticLabel).toList();
      expect(
        labels,
        [
          'Add task',
          'Add event',
          'Add meal',
          'Add medicine',
          'Add habit',
          'Add health measurement',
          'Add expense',
          'Add water',
        ],
      );
    });
  });

  group('showQuickAdd surface', () {
    Future<QuickAddAction?> pumpSurface(WidgetTester tester) {
      return showQuickAdd(tester.element(find.byType(Scaffold)));
    }

    Future<void> pumpHost(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SizedBox.shrink())),
      );
    }

    testWidgets('renders reference title, subtitle and grouped actions',
        (tester) async {
      await pumpHost(tester);
      // ignore: discarded_futures
      pumpSurface(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('What would you like to add?'), findsOneWidget);
      expect(find.text('Choose a category to get started'), findsOneWidget);
      expect(find.text('Quick add'), findsOneWidget);
      expect(find.text('TODAY'), findsNothing);
      for (final label in [
        'Task',
        'Event',
        'Meal',
        'Medicine',
        'Habit',
        'Health',
        'Expense',
        'Water',
      ]) {
        expect(find.text(label), findsWidgets);
      }
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping Task returns the task action', (tester) async {
      await pumpHost(tester);
      final future = pumpSurface(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('Task'));
      await tester.pump();
      final selected = await future;
      expect(selected, isNotNull);
      expect(selected!.kind, QuickAddKind.task);
    });

    testWidgets('tapping Event returns the event action', (tester) async {
      await pumpHost(tester);
      final future = pumpSurface(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('Event'));
      await tester.pump();
      final selected = await future;
      expect(selected!.kind, QuickAddKind.event);
    });

    testWidgets('tapping Water returns the water action', (tester) async {
      await pumpHost(tester);
      final future = pumpSurface(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('Water'));
      await tester.pump();
      final selected = await future;
      expect(selected!.kind, QuickAddKind.water);
    });

    testWidgets('tapping Habit returns the habit action', (tester) async {
      await pumpHost(tester);
      final future = pumpSurface(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      await tester.tap(find.text('Habit'));
      await tester.pump();
      final selected = await future;
      expect(selected!.kind, QuickAddKind.habit);
    });

    testWidgets('Android back dismisses with null', (tester) async {
      await pumpHost(tester);
      final future = pumpSurface(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Quick add'), findsOneWidget);

      // Simulate Android back.
      final dynamic widgetsBinding = WidgetsBinding.instance;
      await widgetsBinding.handlePopRoute();
      await tester.pump();
      final selected = await future;
      expect(selected, isNull);
    });
  });
}
