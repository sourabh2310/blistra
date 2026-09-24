import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/dashboard/models/dashboard_response.dart';
import 'package:frontend/features/dashboard/screens/dashboard_screen.dart'
    show buildTimeline;

DashboardResponse _response({
  List<TaskSummary> todayTasks = const [],
  List<TaskSummary> overdueTasks = const [],
  List<EventSummary> todayEvents = const [],
  List<DoseSummary> doses = const [],
  int dosesTaken = 0,
  int expectedHabits = 0,
  int completedHabits = 0,
  List<HabitSummary> todayHabits = const [],
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
