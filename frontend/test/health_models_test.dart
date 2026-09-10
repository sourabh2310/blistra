import 'package:flutter_test/flutter_test.dart';

import '../lib/features/health/health_models.dart';

void main() {
  group('HealthProfile', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 'p-1',
        'heightCm': 180.5,
        'bloodType': 'O_POSITIVE',
        'dateOfBirth': '1990-01-01',
        'createdAt': '2024-01-01T12:00:00Z',
        'updatedAt': '2024-01-02T12:00:00Z',
      };
      final profile = HealthProfile.fromJson(json);
      expect(profile.id, 'p-1');
      expect(profile.heightCm, 180.5);
      expect(profile.bloodType, BloodType.oPositive);
      expect(profile.dateOfBirth, DateTime(1990, 1, 1));
      expect(profile.createdAt, DateTime.parse('2024-01-01T12:00:00Z'));
      expect(profile.updatedAt, DateTime.parse('2024-01-02T12:00:00Z'));
    });

    test('fromJson handles missing optional fields', () {
      final json = {'id': 'p-2'};
      final profile = HealthProfile.fromJson(json);
      expect(profile.id, 'p-2');
      expect(profile.heightCm, isNull);
      expect(profile.bloodType, isNull);
      expect(profile.dateOfBirth, isNull);
    });
  });

  group('HealthMeasurement', () {
    test('fromJson parses blood pressure with diastolic', () {
      final json = {
        'id': 'm-1',
        'type': 'BLOOD_PRESSURE',
        'measuredAt': '2024-01-01T08:00:00Z',
        'value': 120,
        'valueDiastolic': 80,
        'unit': 'MMHG',
        'source': 'manual',
        'notes': 'Morning reading',
      };
      final m = HealthMeasurement.fromJson(json);
      expect(m.id, 'm-1');
      expect(m.type, MeasurementType.bloodPressure);
      expect(m.value, 120);
      expect(m.valueDiastolic, 80);
      expect(m.unit, 'MMHG');
    });

    test('fromJson falls back to weight for unknown type', () {
      final json = {
        'id': 'm-2',
        'type': 'UNKNOWN_TYPE',
        'measuredAt': '2024-01-01T08:00:00Z',
        'value': 70,
        'unit': 'KG',
      };
      final m = HealthMeasurement.fromJson(json);
      expect(m.type, MeasurementType.weight);
    });
  });

  group('HealthSleepRecord', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 's-1',
        'startedAt': '2024-01-01T22:00:00Z',
        'endedAt': '2024-01-02T06:00:00Z',
        'durationMinutes': 480,
        'rating': 4,
        'notes': 'Good sleep',
      };
      final s = HealthSleepRecord.fromJson(json);
      expect(s.id, 's-1');
      expect(s.startedAt, DateTime.parse('2024-01-01T22:00:00Z'));
      expect(s.endedAt, DateTime.parse('2024-01-02T06:00:00Z'));
      expect(s.durationMinutes, 480);
      expect(s.rating, 4);
      expect(s.notes, 'Good sleep');
    });
  });

  group('HealthActivity', () {
    test('fromJson parses running activity', () {
      final json = {
        'id': 'a-1',
        'type': 'RUNNING',
        'performedAt': '2024-01-01T07:00:00Z',
        'durationMinutes': 30,
        'distanceKm': 5.2,
        'caloriesBurned': 350,
      };
      final a = HealthActivity.fromJson(json);
      expect(a.id, 'a-1');
      expect(a.type, ActivityType.running);
      expect(a.durationMinutes, 30);
      expect(a.distanceKm, 5.2);
      expect(a.caloriesBurned, 350);
    });
  });

  group('HealthLogEntry', () {
    test('fromJson parses with severity', () {
      final json = {
        'id': 'l-1',
        'title': 'Headache',
        'description': 'Mild tension headache',
        'observedAt': '2024-01-01T14:00:00Z',
        'severity': 'MODERATE',
        'notes': 'Took ibuprofen',
      };
      final l = HealthLogEntry.fromJson(json);
      expect(l.id, 'l-1');
      expect(l.title, 'Headache');
      expect(l.severity, Severity.moderate);
    });
  });

  group('HealthEvent', () {
    test('fromJson parses vaccination', () {
      final json = {
        'id': 'e-1',
        'type': 'VACCINATION',
        'title': 'Flu shot',
        'occurredAt': '2024-10-15T10:00:00Z',
        'notes': 'Annual flu vaccine',
      };
      final e = HealthEvent.fromJson(json);
      expect(e.id, 'e-1');
      expect(e.type, EventType.vaccination);
      expect(e.title, 'Flu shot');
    });
  });

  group('HealthAppointment', () {
    test('fromJson parses confirmed appointment', () {
      final json = {
        'id': 'ap-1',
        'title': 'Dentist',
        'scheduledAt': '2024-02-01T09:00:00Z',
        'location': 'Smile Clinic',
        'status': 'CONFIRMED',
      };
      final ap = HealthAppointment.fromJson(json);
      expect(ap.id, 'ap-1');
      expect(ap.title, 'Dentist');
      expect(ap.status, AppointmentStatus.confirmed);
    });
  });

  group('HealthPage', () {
    test('fromJson deserializes page envelope', () {
      final json = {
        'content': [
          {'id': 'm-1', 'type': 'WEIGHT', 'measuredAt': '2024-01-01T08:00:00Z',
           'value': 70, 'unit': 'KG', 'valueDiastolic': null, 'source': null,
           'notes': null, 'createdAt': null, 'updatedAt': null},
          {'id': 'm-2', 'type': 'HEIGHT', 'measuredAt': '2024-01-01T08:00:00Z',
           'value': 180, 'unit': 'CM', 'valueDiastolic': null, 'source': null,
           'notes': null, 'createdAt': null, 'updatedAt': null},
        ],
        'page': 0,
        'size': 20,
        'totalElements': 2,
        'totalPages': 1,
        'last': true,
      };
      final page = HealthPage.fromJson(json, HealthMeasurement.fromJson);
      expect(page.content.length, 2);
      expect(page.page, 0);
      expect(page.size, 20);
      expect(page.totalElements, 2);
      expect(page.totalPages, 1);
      expect(page.last, true);
    });
  });

  group('MeasurementInput toJson', () {
    test('serializes blood pressure with both values', () {
      final input = MeasurementInput(
        type: MeasurementType.bloodPressure,
        measuredAt: DateTime.parse('2024-01-01T08:00:00Z'),
        value: 120,
        valueDiastolic: 80,
        unit: 'MMHG',
        source: 'omron',
        notes: 'morning',
      );
      final json = input.toJson();
      expect(json['type'], 'BLOOD_PRESSURE');
      expect(json['value'], 120);
      expect(json['valueDiastolic'], 80);
      expect(json['unit'], 'MMHG');
      expect(json['source'], 'omron');
      expect(json['notes'], 'morning');
      // measuredAt is UTC ISO string
      expect(json['measuredAt'], endsWith('Z'));
    });

    test('omits null optional fields', () {
      final input = MeasurementInput(
        type: MeasurementType.weight,
        measuredAt: DateTime.parse('2024-01-01T08:00:00Z'),
        value: 70.5,
        unit: 'KG',
      );
      final json = input.toJson();
      expect(json.containsKey('valueDiastolic'), isFalse);
      expect(json.containsKey('source'), isFalse);
      expect(json.containsKey('notes'), isFalse);
    });
  });

  group('format helpers', () {
    test('formatDouble trims trailing zeros', () {
      expect(formatDouble(70.0), '70');
      expect(formatDouble(70.5), '70.5');
      expect(formatDouble(null), '');
    });

    test('formatMinutes renders minutes', () {
      expect(formatMinutes(45), '45 min');
      expect(formatMinutes(null), '');
    });

    test('formatDate renders local date', () {
      final date = DateTime(2024, 1, 15, 12, 30);
      expect(formatDate(date), '2024-01-15');
      expect(formatDate(null), '');
    });

    test('formatDateTime renders local date-time', () {
      final dt = DateTime(2024, 1, 15, 12, 5);
      expect(formatDateTime(dt), '2024-01-15 12:05');
      expect(formatDateTime(null), '');
    });
  });

  group('enum wire values', () {
    test('MeasurementType wire matches backend enum names', () {
      expect(MeasurementType.weight.wire, 'WEIGHT');
      expect(MeasurementType.height.wire, 'HEIGHT');
      expect(MeasurementType.heartRate.wire, 'HEART_RATE');
      expect(MeasurementType.temperature.wire, 'TEMPERATURE');
      expect(MeasurementType.bloodPressure.wire, 'BLOOD_PRESSURE');
    });

    test('fromWire parses backend names', () {
      expect(MeasurementType.fromWire('HEART_RATE'), MeasurementType.heartRate);
      expect(MeasurementType.fromWire('BLOOD_PRESSURE'), MeasurementType.bloodPressure);
      expect(MeasurementType.fromWire('INVALID'), isNull);
    });

    test('BloodType wire covers all variants', () {
      expect(BloodType.aPositive.wire, 'A_POSITIVE');
      expect(BloodType.unknown.wire, 'UNKNOWN');
    });

    test('Severity wire values', () {
      expect(Severity.mild.wire, 'MILD');
      expect(Severity.moderate.wire, 'MODERATE');
      expect(Severity.severe.wire, 'SEVERE');
    });

    test('ActivityType wire values', () {
      expect(ActivityType.strengthTraining.wire, 'STRENGTH_TRAINING');
      expect(ActivityType.yoga.wire, 'YOGA');
    });

    test('EventType wire values', () {
      expect(EventType.medicalVisit.wire, 'MEDICAL_VISIT');
      expect(EventType.labTest.wire, 'LAB_TEST');
    });

    test('AppointmentStatus wire values', () {
      expect(AppointmentStatus.scheduled.wire, 'SCHEDULED');
      expect(AppointmentStatus.cancelled.wire, 'CANCELLED');
    });
  });
}