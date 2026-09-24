/// Focused Quick Add tests: action set, premium surface, dismissal.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/widgets/quick_add.dart';

void main() {
  group('quickAddActions', () {
    test('exposes exactly the six real creation flows', () {
      final actions = quickAddActions;
      expect(actions, hasLength(6));
      expect(
        actions.map((a) => a.label).toList(),
        ['Task', 'Event', 'Medicine', 'Meal', 'Water', 'Habit'],
      );
      // Stable identities, one per flow.
      expect(
        actions.map((a) => a.kind).toSet(),
        hasLength(6),
      );
    });

    test('Task/Event are primary (first two)', () {
      final actions = quickAddActions;
      expect(actions[0].kind, QuickAddKind.task);
      expect(actions[1].kind, QuickAddKind.event);
    });

    test('descriptions match actual functionality', () {
      final byKind = {for (final a in quickAddActions) a.kind: a};
      expect(byKind[QuickAddKind.task]!.description,
          'Something you need to get done');
      expect(byKind[QuickAddKind.event]!.description,
          'Schedule a time-bound commitment');
      expect(byKind[QuickAddKind.medicine]!.description,
          'Record or schedule a medicine');
      expect(byKind[QuickAddKind.meal]!.description, 'Add a meal or food');
      expect(
          byKind[QuickAddKind.water]!.description, 'Log your water intake');
      expect(byKind[QuickAddKind.habit]!.description,
          'Create or complete a habit');
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
          'Add medicine',
          'Add meal',
          'Add water',
          'Add habit',
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

    testWidgets('renders premium title, subtitle and grouped actions',
        (tester) async {
      await pumpHost(tester);
      // ignore: discarded_futures
      pumpSurface(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Quick add'), findsOneWidget);
      expect(find.text('What would you like to add?'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
      // No generic MORE overflow section: exactly six destinations.
      expect(find.text('MORE'), findsNothing);
      for (final label in ['Task', 'Event', 'Medicine', 'Meal', 'Water', 'Habit']) {
        expect(find.text(label), findsWidgets);
      }
      // No duplicate bottom navigation inside the sheet.
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
