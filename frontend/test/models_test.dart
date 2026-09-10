import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/medicines/models/medicine.dart';
import 'package:frontend/features/medicines/models/medicine_enums.dart';
import 'package:frontend/features/medicines/models/schedule.dart';
import 'package:frontend/features/medicines/models/dose_record.dart';
import 'package:frontend/features/medicines/models/refill.dart';
import 'package:frontend/features/medicines/models/page.dart';

void main() {
  group('MedicineStatus', () {
    test('fromWire maps all variants', () {
      expect(MedicineStatus.fromWire('ACTIVE'), equals(MedicineStatus.active));
      expect(MedicineStatus.fromWire('PAUSED'), equals(MedicineStatus.paused));
      expect(MedicineStatus.fromWire('COMPLETED'), equals(MedicineStatus.completed));
      expect(MedicineStatus.fromWire('ARCHIVED'), equals(MedicineStatus.archived));
      expect(MedicineStatus.fromWire('UNKNOWN'), equals(MedicineStatus.active));
    });
  });

  group('ScheduleType', () {
    test('fromWire maps all variants', () {
      expect(ScheduleType.fromWire('DAILY'), equals(ScheduleType.daily));
      expect(ScheduleType.fromWire('WEEKLY'), equals(ScheduleType.weekly));
      expect(ScheduleType.fromWire('CUSTOM_DAYS'), equals(ScheduleType.customDays));
      expect(ScheduleType.fromWire('AS_NEEDED'), equals(ScheduleType.asNeeded));
      expect(ScheduleType.fromWire('UNKNOWN'), equals(ScheduleType.daily));
    });
  });

  group('DoseStatus', () {
    test('fromWire maps all variants', () {
      expect(DoseStatus.fromWire('TAKEN'), equals(DoseStatus.taken));
      expect(DoseStatus.fromWire('MISSED'), equals(DoseStatus.missed));
      expect(DoseStatus.fromWire('SKIPPED'), equals(DoseStatus.skipped));
      expect(DoseStatus.fromWire('UNKNOWN'), equals(DoseStatus.taken));
    });
  });

  group('Medicine.fromJson', () {
    test('parses full response', () {
      final json = {
        'id': 'med-1',
        'name': 'Metformin',
        'genericName': 'Metformin HCl',
        'form': 'Tablet',
        'strength': 500,
        'strengthUnit': 'mg',
        'notes': 'Take with food',
        'status': 'ACTIVE',
        'startDate': '2026-01-01',
        'endDate': '2026-12-31',
        'createdAt': '2026-01-01T08:00:00',
        'updatedAt': '2026-01-01T08:00:00',
      };

      final m = Medicine.fromJson(json);

      expect(m.id, 'med-1');
      expect(m.name, 'Metformin');
      expect(m.genericName, 'Metformin HCl');
      expect(m.form, 'Tablet');
      expect(m.strength, 500);
      expect(m.strengthUnit, 'mg');
      expect(m.notes, 'Take with food');
      expect(m.status, MedicineStatus.active);
      expect(m.startDate?.year, 2026);
      expect(m.endDate?.year, 2026);
    });

    test('handles null optional fields', () {
      final json = {
        'id': 'med-2',
        'name': 'Aspirin',
        'status': 'PAUSED',
        'createdAt': '2026-01-01T08:00:00',
        'updatedAt': '2026-01-01T08:00:00',
      };

      final m = Medicine.fromJson(json);

      expect(m.genericName, isNull);
      expect(m.form, isNull);
      expect(m.strength, isNull);
      expect(m.strengthUnit, isNull);
      expect(m.notes, isNull);
      expect(m.startDate, isNull);
      expect(m.endDate, isNull);
    });

    test('strengthLabel formats correctly', () {
      expect(Medicine.fromJson({'id':'1','name':'X','status':'ACTIVE','createdAt':'2026-01-01T08:00:00','updatedAt':'2026-01-01T08:00:00'}).strengthLabel, '');
      expect(Medicine.fromJson({'id':'1','name':'X','status':'ACTIVE','strength':500,'strengthUnit':'mg','createdAt':'2026-01-01T08:00:00','updatedAt':'2026-01-01T08:00:00'}).strengthLabel, '500 mg');
      expect(Medicine.fromJson({'id':'1','name':'X','status':'ACTIVE','strength':500.5,'strengthUnit':'mg','createdAt':'2026-01-01T08:00:00','updatedAt':'2026-01-01T08:00:00'}).strengthLabel, '500.5 mg');
    });
  });

  group('Schedule.fromJson', () {
    test('parses DAILY schedule', () {
      final json = {
        'id': 'sched-1',
        'medicineId': 'med-1',
        'scheduleType': 'DAILY',
        'times': ['08:00', '20:00'],
        'daysOfWeek': [],
        'doseAmount': 500,
        'doseUnit': 'mg',
        'startDate': '2026-01-01',
        'endDate': null,
        'active': true,
        'createdAt': '2026-01-01T08:00:00',
        'updatedAt': '2026-01-01T08:00:00',
      };

      final s = Schedule.fromJson(json);

      expect(s.id, 'sched-1');
      expect(s.medicineId, 'med-1');
      expect(s.scheduleType, ScheduleType.daily);
      expect(s.times, ['08:00', '20:00']);
      expect(s.daysOfWeek, isEmpty);
      expect(s.doseAmount, 500);
      expect(s.doseUnit, 'mg');
      expect(s.active, isTrue);
    });

    test('parses WEEKLY schedule with days', () {
      final json = {
        'id': 'sched-2',
        'medicineId': 'med-1',
        'scheduleType': 'WEEKLY',
        'times': ['09:00'],
        'daysOfWeek': ['MONDAY', 'WEDNESDAY', 'FRIDAY'],
        'doseAmount': 250,
        'doseUnit': 'mg',
        'startDate': '2026-01-01',
        'endDate': '2026-06-30',
        'active': true,
        'createdAt': '2026-01-01T08:00:00',
        'updatedAt': '2026-01-01T08:00:00',
      };

      final s = Schedule.fromJson(json);

      expect(s.scheduleType, ScheduleType.weekly);
      expect(s.times, ['09:00']);
      expect(s.daysOfWeek, [1, 3, 5]); // Mon=1, Wed=3, Fri=5
    });
  });

  group('DoseRecord.fromJson', () {
    test('parses TAKEN dose', () {
      final json = {
        'id': 'dose-1',
        'medicineId': 'med-1',
        'scheduleId': 'sched-1',
        'status': 'TAKEN',
        'scheduledAt': '2026-01-01T08:00:00+05:30',
        'takenAt': '2026-01-01T08:05:00+05:30',
        'note': 'After breakfast',
        'createdAt': '2026-01-01T08:05:00',
        'updatedAt': '2026-01-01T08:05:00',
      };

      final d = DoseRecord.fromJson(json);

      expect(d.id, 'dose-1');
      expect(d.medicineId, 'med-1');
      expect(d.scheduleId, 'sched-1');
      expect(d.status, DoseStatus.taken);
      expect(d.scheduledAt.isAfter(DateTime(2026)), isTrue);
      expect(d.takenAt, isNotNull);
      expect(d.note, 'After breakfast');
    });

    test('handles MISSED with null takenAt', () {
      final json = {
        'id': 'dose-2',
        'medicineId': 'med-1',
        'scheduleId': null,
        'status': 'MISSED',
        'scheduledAt': '2026-01-01T20:00:00+05:30',
        'takenAt': null,
        'note': null,
        'createdAt': '2026-01-01T20:00:00',
        'updatedAt': '2026-01-01T20:00:00',
      };

      final d = DoseRecord.fromJson(json);

      expect(d.status, DoseStatus.missed);
      expect(d.takenAt, isNull);
      expect(d.scheduleId, isNull);
      expect(d.note, isNull);
    });
  });

  group('Refill.fromJson', () {
    test('parses refill record', () {
      final json = {
        'id': 'refill-1',
        'medicineId': 'med-1',
        'refillDate': '2026-01-15',
        'quantity': 60,
        'remainingQuantity': 60,
        'notes': 'Pharmacy pickup',
        'createdAt': '2026-01-15T10:00:00',
        'updatedAt': '2026-01-15T10:00:00',
      };

      final r = Refill.fromJson(json);

      expect(r.id, 'refill-1');
      expect(r.medicineId, 'med-1');
      expect(r.refillDate.year, 2026);
      expect(r.quantity, 60);
      expect(r.remainingQuantity, 60);
      expect(r.notes, 'Pharmacy pickup');
    });

    test('handles null remainingQuantity', () {
      final json = {
        'id': 'refill-2',
        'medicineId': 'med-1',
        'refillDate': '2026-02-01',
        'quantity': 30,
        'remainingQuantity': null,
        'notes': null,
        'createdAt': '2026-02-01T10:00:00',
        'updatedAt': '2026-02-01T10:00:00',
      };

      final r = Refill.fromJson(json);

      expect(r.remainingQuantity, isNull);
      expect(r.remainingLabel, '—');
    });
  });

  group('Page.fromJson', () {
    test('parses paginated response', () {
      final json = {
        'content': [
          {'id': '1', 'name': 'A', 'status': 'ACTIVE', 'createdAt': '2026-01-01T08:00:00', 'updatedAt': '2026-01-01T08:00:00'},
          {'id': '2', 'name': 'B', 'status': 'PAUSED', 'createdAt': '2026-01-02T08:00:00', 'updatedAt': '2026-01-02T08:00:00'},
        ],
        'page': 0,
        'size': 50,
        'totalElements': 2,
        'totalPages': 1,
        'last': true,
      };

      final page = Page.fromJson(json, Medicine.fromJson);

      expect(page.content.length, 2);
      expect(page.page, 0);
      expect(page.size, 50);
      expect(page.totalElements, 2);
      expect(page.totalPages, 1);
      expect(page.last, isTrue);
    });
  });
}