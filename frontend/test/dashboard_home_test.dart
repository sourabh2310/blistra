import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/models/dashboard_response.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart'
    show buildAttentionItems, buildTimeline, computeHomeOverview;

DashboardResponse _response({
  List<TaskSummary> todayTasks = const [],
  List<TaskSummary> overdueTasks = const [],
  List<EventSummary> todayEvents = const [],
  List<DoseSummary> doses = const [],
  int dosesTaken = 0,
  int expectedHabits = 0,
  int completedHabits = 0,
  List<HabitSummary> todayHabits = const [],
  FinanceSection? finance,
  WeekSection? week,
}) {
  return DashboardResponse(
    date: DateTime(2026, 9, 24),
    generatedAt: DateTime(2026, 9, 24, 8),
    planner: PlannerSection(
      overdueTasks: overdueTasks,
      todayTasks: todayTasks,
      todayEvents: todayEvents,
      unavailable: false,
    ),
    medicines: MedicineSection(
      activeMedicineCount: doses.isEmpty ? 0 : 1,
      dosesToday: doses,
      dosesTakenToday: dosesTaken,
      dosesRemainingToday: doses.length - dosesTaken,
      unavailable: false,
    ),
    finance: finance,
    week: week,
    habits: HabitSection(
      activeHabitCount: expectedHabits,
      expectedToday: expectedHabits,
      completedToday: completedHabits,
      remainingToday: expectedHabits - completedHabits,
      todayHabits: todayHabits,
      unavailable: false,
    ),
  );
}

TaskSummary _task(String title, String status) => TaskSummary(
      id: title,
      title: title,
      status: status,
      dueAt: '2026-09-24T10:00:00+05:30',
    );

CurrencySection _currency(String currency, String expense) => CurrencySection(
      currency: currency,
      income: '0',
      expense: expense,
      net: '-${expense}',
      transferIn: '0',
      transferOut: '0',
      topCategories: const [],
    );

DoseSummary _dose(String name, String status, String at) => DoseSummary(
      id: name,
      medicineId: 'm-$name',
      medicineName: name,
      status: status,
      scheduledAt: at,
    );

void main() {
  group('greetingForHour', () {
    test('follows spec windows', () {
      expect(greetingForHour(5), 'Good morning');
      expect(greetingForHour(11), 'Good morning');
      expect(greetingForHour(12), 'Good afternoon');
      expect(greetingForHour(16), 'Good afternoon');
      expect(greetingForHour(17), 'Good evening');
      expect(greetingForHour(20), 'Good evening');
      expect(greetingForHour(21), 'Good night');
      expect(greetingForHour(4), 'Good night');
      expect(greetingForHour(0), 'Good night');
    });
  });

  group('resolveDisplayName', () {
    test('prefers backend firstName, then displayName, then email', () {
      expect(
        resolveDisplayName(
            user: DashboardUser(
                email: 'x@y.z', displayName: 'Sourabh Patel', firstName: 'Sourabh')),
        'Sourabh',
      );
      expect(
        resolveDisplayName(
            user: DashboardUser(email: 'x@y.z', displayName: 'Sourabh Patel')),
        'Sourabh',
      );
      expect(resolveDisplayName(email: 'sourabh.patel@example.com'), 'Sourabh');
      expect(resolveDisplayName(email: ''), 'there');
      expect(resolveDisplayName(), 'there');
    });

    test('never returns hardcoded persona', () {
      expect(resolveDisplayName(email: ''), isNot('Aarav'));
      expect(resolveDisplayName(email: 'test@example.com'), isNot('Aarav'));
    });
  });

  group('initialsForName', () {
    test('derives initials from real name', () {
      expect(initialsForName('Sourabh Patel'), 'SP');
      expect(initialsForName('Sourabh'), 'SO');
      expect(initialsForName('there'), '');
      expect(initialsForName(''), '');
    });
  });

  group('dayStatusText', () {
    test('deterministic thresholds', () {
      expect(dayStatusText(1.0), "You're all caught up");
      expect(dayStatusText(0.8), "You're almost there");
      expect(dayStatusText(0.6), "You're making good progress");
      expect(dayStatusText(0.3), "Let's keep moving");
      expect(dayStatusText(0.0), "Let's get your day started");
    });
  });

  group('computeDayProgress', () {
    test('empty dashboard yields No priorities yet', () {
      final p = computeDayProgress(null);
      expect(p.isEmpty, isTrue);
      expect(p.label, 'No priorities yet');
      expect(p.pct, isNull);
    });

    test('aggregates planner + medicines + habits', () {
      final d = _response(
        todayTasks: [_task('t1', 'PENDING'), _task('t2', 'COMPLETED')],
        doses: [
          _dose('Med A', 'TAKEN', '2026-09-24T08:00:00+05:30'),
          _dose('Med B', 'PENDING', '2026-09-24T20:00:00+05:30'),
        ],
        dosesTaken: 1,
        expectedHabits: 2,
        completedHabits: 1,
      );
      final p = computeDayProgress(d, now: DateTime(2026, 9, 24, 9));
      // planner 2 (1 done) + meds 2 (1 done) + habits 2 (1 done) = 6/3
      expect(p.total, 6);
      expect(p.completed, 3);
      expect(p.pct, closeTo(0.5, 0.001));
      expect(p.label, '3 of 6 priorities completed');
    });

    test('user with no data gets zero total, not fake numbers', () {
      final d = _response();
      final p = computeDayProgress(d);
      expect(p.total, 0);
      expect(p.completed, 0);
    });
  });

  group('buildTimeline', () {
    test('merges and sorts real records ASC', () {
      final d = _response(
        todayEvents: [
          EventSummary(
              id: 'e1',
              title: 'Team sync',
              startAt: '2026-09-24T10:00:00+05:30',
              endAt: '2026-09-24T11:00:00+05:30'),
        ],
        doses: [_dose('Med A', 'PENDING', '2026-09-24T08:00:00+05:30')],
      );
      final items =
          buildTimeline(d, now: DateTime(2026, 9, 24, 7), limit: 5);
      expect(items.length, 2);
      expect(items.first.title, 'Med A');
      expect(items.last.title, 'Team sync');
    });

    test('empty dashboard yields empty timeline (no fake rows)', () {
      expect(buildTimeline(_response(), now: DateTime(2026, 9, 24, 7)), isEmpty);
      expect(buildTimeline(null, now: DateTime(2026, 9, 24, 7)), isEmpty);
    });
  });

  group('Home helpers', () {
    test('overview uses real schedules and today finance', () {
      final d = _response(
        todayTasks: [_task('t1', 'PENDING')],
        doses: [
          _dose('Med A', 'TAKEN', '2026-09-24T08:00:00+05:30'),
          _dose('Med B', 'PENDING', '2026-09-24T20:00:00+05:30'),
        ],
        expectedHabits: 2,
        completedHabits: 1,
        finance: FinanceSection(
          from: DateTime(2026, 9, 1),
          to: DateTime(2026, 9, 30),
          currencies: const [],
          today: FinanceToday(
            from: DateTime(2026, 9, 24),
            to: DateTime(2026, 9, 24),
            currencies: [_currency('USD', '12.50')],
          ),
          unavailable: false,
        ),
      );
      final overview = computeHomeOverview(d);
      expect(overview.metrics.map((item) => item.value), containsAll(['1', '1 of 2', '12.50']));
    });

    test('timeline puts due habits at Anytime', () {
      final d = _response(
        todayHabits: [
          HabitSummary(
            id: 'h1',
            name: 'Read',
            completedToday: false,
          ),
        ],
      );
      final item = buildTimeline(
        d,
        now: DateTime(2026, 9, 24, 15),
      ).single;
      expect(item.anytime, isTrue);
      expect(item.title, 'Read');
    });

    test('attention includes overdue task and medicine', () {
      final d = _response(
        overdueTasks: [_task('Old task', 'PENDING')],
        doses: [_dose('Med A', 'PENDING', '2026-09-24T08:00:00+05:30')],
      );
      final items = buildAttentionItems(
        d,
        now: DateTime(2026, 9, 24, 15),
      );
      expect(items.map((item) => item.title), containsAll(['Old task', 'Med A']));
    });

    test('weekly model accepts new and legacy field names', () {
      final model = DashboardResponse.fromJson({
        'date': '2026-09-24',
        'generatedAt': '2026-09-24T08:00:00',
        'week': {
          'start': '2026-09-21',
          'end': '2026-09-27',
          'completedTasks': 2,
          'tasksDueOrScheduled': 4,
          'habitCompletions': 3,
          'expectedHabitOccurrences': 5,
          'activeDays': 3,
        },
        'finance': {
          'from': '2026-09-01',
          'to': '2026-09-30',
          'currencies': [],
          'today': {
            'from': '2026-09-24',
            'to': '2026-09-24',
            'currencies': [_currency('EUR', '4').toJson()],
          },
        },
      });
      expect(model.week!.tasksDue, 4);
      expect(model.week!.habitOccurrences, 5);
      expect(model.finance!.today!.currencies.single.expense, '4');
      final roundTrip = DashboardResponse.fromJson(model.toJson());
      expect(roundTrip.week!.activeDays, 3);
      expect(roundTrip.finance!.today!.currencies.single.currency, 'EUR');
    });
  });

  group('DashboardUser JSON', () {
    test('round-trips and tolerates absence (backward compatible)', () {
      final r = DashboardResponse(
        date: DateTime(2026, 9, 24),
        generatedAt: DateTime(2026, 9, 24, 8),
        user: DashboardUser(
            email: 'sourabh@example.com',
            displayName: 'Sourabh Patel',
            firstName: 'Sourabh'),
      );
      final json = r.toJson();
      expect((json['user'] as Map)['firstName'], 'Sourabh');
      final back = DashboardResponse.fromJson({
        'date': '2026-09-24',
        'generatedAt': '2026-09-24T08:00:00+05:30',
      });
      expect(back.user, isNull);
    });
  });
}
