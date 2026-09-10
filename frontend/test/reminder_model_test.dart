import 'package:test/test.dart';

import 'package:frontend/features/notifications/models/reminder.dart';
import 'package:frontend/features/notifications/models/reminder_type.dart';

void main() {
  group('Reminder.fromJson', () {
    test('parses all fields including UTC scheduledAt', () {
      final json = {
        'id': 'r1',
        'type': 'GENERAL',
        'title': 'Take a break',
        'body': 'Stretch your legs',
        'scheduledAt': '2026-09-15T14:30:00Z',
        'timezone': 'UTC',
        'status': 'SCHEDULED',
        'sourceId': null,
      };

      final reminder = Reminder.fromJson(json);

      expect(reminder.id, 'r1');
      expect(reminder.type, ReminderType.general);
      expect(reminder.title, 'Take a break');
      expect(reminder.body, 'Stretch your legs');
      expect(reminder.scheduledAt.isUtc, isTrue);
      expect(reminder.scheduledAt.toIso8601String(), '2026-09-15T14:30:00.000Z');
      expect(reminder.timezone, 'UTC');
      expect(reminder.status, ReminderStatus.scheduled);
      expect(reminder.sourceId, isNull);
      expect(reminder.isActive, isTrue);
    });

    test('parses cancelled reminder', () {
      final json = {
        'id': 'r2',
        'type': 'GENERAL',
        'title': 'Cancelled',
        'body': null,
        'scheduledAt': '2026-09-15T14:30:00Z',
        'timezone': 'UTC',
        'status': 'CANCELLED',
        'sourceId': null,
      };

      final reminder = Reminder.fromJson(json);

      expect(reminder.status, ReminderStatus.cancelled);
      expect(reminder.isActive, isFalse);
    });

    test('parses domain reminder type', () {
      final json = {
        'id': 'r3',
        'type': 'MEDICINE',
        'title': 'Aspirin',
        'body': null,
        'scheduledAt': '2026-09-15T14:30:00Z',
        'timezone': 'UTC',
        'status': 'SCHEDULED',
        'sourceId': 'med-123',
      };

      final reminder = Reminder.fromJson(json);

      expect(reminder.type, ReminderType.medicine);
      expect(reminder.type.isDomainType, isTrue);
      expect(reminder.sourceId, 'med-123');
    });

    test('round-trip: toJson then fromJson preserves fields', () {
      final original = {
        'id': 'r4',
        'type': 'HABIT',
        'title': 'Read',
        'body': '30 min',
        'scheduledAt': '2026-09-15T14:30:00Z',
        'timezone': 'America/New_York',
        'status': 'SCHEDULED',
        'sourceId': 'habit-7',
      };

      final reminder = Reminder.fromJson(original);
      final roundTrip = reminder.toJson();

      expect(roundTrip['id'], original['id']);
      expect(roundTrip['type'], original['type']);
      expect(roundTrip['title'], original['title']);
      expect(roundTrip['body'], original['body']);
      expect(roundTrip['scheduledAt'], original['scheduledAt']);
      expect(roundTrip['timezone'], original['timezone']);
      expect(roundTrip['status'], original['status']);
      expect(roundTrip['sourceId'], original['sourceId']);
    });
  });
}