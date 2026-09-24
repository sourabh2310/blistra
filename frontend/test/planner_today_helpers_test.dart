import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/planner/models/task.dart';
import 'package:frontend/features/planner/models/task_priority.dart';
import 'package:frontend/features/planner/models/task_status.dart';
import 'package:frontend/features/planner/today_helpers.dart';

void main() {
  group('computeTodaySummary', () {
    test('empty list yields "No plans yet"', () {
      final s = computeTodaySummary(const []);
      expect(s.total, 0);
      expect(s.completed, 0);
      expect(s.remaining, 0);
      expect(s.label, 'No plans yet');
    });

    test('counts real totals, excludes cancelled', () {
      final now = DateTime(2026, 9, 24, 12);
      final s = computeTodaySummary([
        TimelineEntry(
            at: now, title: 'A', source: 'Task', done: true),
        TimelineEntry(
            at: now, title: 'B', source: 'Event', done: false),
        TimelineEntry(
            at: now,
            title: 'C',
            source: 'Task',
            done: false,
            cancelled: true),
      ]);
      expect(s.total, 2);
      expect(s.completed, 1);
      expect(s.remaining, 1);
    });
  });

  group('sectionEntries', () {
    test('splits overdue / up-next / later / completed', () {
      final now = DateTime(2026, 9, 24, 12);
      final sections = sectionEntries([
        TimelineEntry(
            at: DateTime(2026, 9, 24, 9),
            title: 'Overdue',
            source: 'Task',
            done: false),
        TimelineEntry(
            at: DateTime(2026, 9, 24, 13),
            title: 'Next',
            source: 'Event',
            done: false),
        TimelineEntry(
            at: DateTime(2026, 9, 24, 18),
            title: 'Later',
            source: 'Task',
            done: false),
        TimelineEntry(
            at: DateTime(2026, 9, 24, 8),
            title: 'Done',
            source: 'Habit',
            done: true),
      ], now);
      expect(sections.overdue.map((e) => e.title), ['Overdue']);
      expect(sections.upNext.map((e) => e.title), ['Next']);
      expect(sections.laterToday.map((e) => e.title), ['Later']);
      expect(sections.completed.map((e) => e.title), ['Done']);
    });

    test('empty input yields empty sections', () {
      final sections =
          sectionEntries(const [], DateTime(2026, 9, 24, 12));
      expect(sections.overdue, isEmpty);
      expect(sections.upNext, isEmpty);
      expect(sections.laterToday, isEmpty);
      expect(sections.completed, isEmpty);
    });
  });

  group('countByDay', () {
    test('groups counts by local day', () {
      final counts = countByDay([
        TimelineEntry(
            at: DateTime(2026, 9, 24, 9),
            title: 'A',
            source: 'Task',
            done: false),
        TimelineEntry(
            at: DateTime(2026, 9, 24, 18),
            title: 'B',
            source: 'Event',
            done: false),
        TimelineEntry(
            at: DateTime(2026, 9, 25, 9),
            title: 'C',
            source: 'Task',
            done: false),
      ]);
      expect(counts[DateTime(2026, 9, 24)], 2);
      expect(counts[DateTime(2026, 9, 25)], 1);
    });
  });

  group('task schedule grouping', () {
    PlannerTask task(
      String id, {
      DateTime? dueDate,
      DateTime? dueTime,
      bool overdue = false,
      TaskStatus status = TaskStatus.todo,
    }) {
      return PlannerTask(
        id: id,
        title: id,
        status: status,
        priority: TaskPriority.medium,
        overdue: overdue,
        dueDate: dueDate,
        dueTime: dueTime,
      );
    }

    test('distinguishes timed and untimed tasks without inventing times', () {
      expect(taskHasExplicitTime(task('timed', dueTime: DateTime(2000, 1, 1, 9))), isTrue);
      expect(taskHasExplicitTime(task('untimed', dueDate: DateTime(2026, 9, 24))), isFalse);
    });

    test('creates only non-empty Overdue Today Tomorrow Upcoming No date groups', () {
      final groups = groupTasksByDate([
        task('overdue', dueDate: DateTime(2026, 9, 23), overdue: true),
        task('today', dueDate: DateTime(2026, 9, 24)),
        task('tomorrow', dueDate: DateTime(2026, 9, 25)),
        task('later', dueDate: DateTime(2026, 9, 30)),
        task('undated'),
        task('done', dueDate: DateTime(2026, 9, 24), status: TaskStatus.completed),
      ], DateTime(2026, 9, 24, 12));
      expect(groups.map((group) => group.label), [
        'Overdue',
        'Today',
        'Tomorrow',
        'Upcoming',
        'No date',
      ]);
      expect(groups.every((group) => group.tasks.isNotEmpty), isTrue);
    });
  });
}
