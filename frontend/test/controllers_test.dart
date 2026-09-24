import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/features/medicines/state/medicine_form_controller.dart';
import 'package:frontend/features/medicines/state/schedule_form_controller.dart';
import 'package:frontend/features/medicines/state/refill_form_controller.dart';
import 'package:frontend/features/medicines/models/medicine.dart';
import 'package:frontend/features/medicines/models/medicine_enums.dart';
import 'package:frontend/features/medicines/models/schedule.dart';
import 'package:frontend/features/medicines/models/refill.dart';
import 'package:frontend/features/medicines/data/medicines_api_client.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

class _FakeMedicinesApiClient extends MedicinesApiClient {
  _FakeMedicinesApiClient({super.httpClient, super.baseUrl});

  @override
  Future<Medicine> createMedicine(Map<String, dynamic> request) async {
    return Medicine.fromJson({
      ...request,
      'id': 'new-med',
      'status': 'ACTIVE',
      'createdAt': '2026-01-01T08:00:00',
      'updatedAt': '2026-01-01T08:00:00',
    });
  }

  @override
  Future<Medicine> updateMedicine(String id, Map<String, dynamic> request) async {
    return Medicine.fromJson({
      ...request,
      'id': id,
      'status': 'ACTIVE',
      'createdAt': '2026-01-01T08:00:00',
      'updatedAt': '2026-01-01T08:00:00',
    });
  }

  @override
  Future<Schedule> createSchedule(String medicineId, Map<String, dynamic> request) async {
    return Schedule.fromJson({
      ...request,
      'id': 'new-sched',
      'medicineId': medicineId,
      'active': true,
      'createdAt': '2026-01-01T08:00:00',
      'updatedAt': '2026-01-01T08:00:00',
    });
  }

  @override
  Future<Schedule> updateSchedule(String medicineId, String scheduleId, Map<String, dynamic> request) async {
    return Schedule.fromJson({
      ...request,
      'id': scheduleId,
      'medicineId': medicineId,
      'active': true,
      'createdAt': '2026-01-01T08:00:00',
      'updatedAt': '2026-01-01T08:00:00',
    });
  }

  @override
  Future<Refill> createRefill(String medicineId, Map<String, dynamic> request) async {
    return Refill.fromJson({
      ...request,
      'id': 'new-refill',
      'medicineId': medicineId,
      'createdAt': '2026-01-01T08:00:00',
      'updatedAt': '2026-01-01T08:00:00',
    });
  }

  @override
  Future<Refill> updateRefill(String medicineId, String refillId, Map<String, dynamic> request) async {
    return Refill.fromJson({
      ...request,
      'id': refillId,
      'medicineId': medicineId,
      'createdAt': '2026-01-01T08:00:00',
      'updatedAt': '2026-01-01T08:00:00',
    });
  }
}

void main() {
  group('MedicineFormController', () {
    late _FakeMedicinesApiClient api;

    setUp(() {
      api = _FakeMedicinesApiClient(
        httpClient: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://test',
      );
    });

    test('validate passes for minimal valid medicine', () {
      final c = MedicineFormController(api);
      c.setName('Metformin');
      expect(c.validate(), isTrue);
      expect(c.hasErrors, isFalse);
    });

    test('validate fails for empty name', () {
      final c = MedicineFormController(api);
      c.setName('   ');
      expect(c.validate(), isFalse);
      expect(c.errorFor('name'), 'Name is required');
    });

    test('validate fails for name > 100 chars', () {
      final c = MedicineFormController(api);
      c.setName('a' * 101);
      expect(c.validate(), isFalse);
      expect(c.errorFor('name'), 'Name must be at most 100 characters');
    });

    test('validate fails for negative strength', () {
      final c = MedicineFormController(api);
      c.setName('Test');
      c.setStrength('-10');
      expect(c.validate(), isFalse);
      expect(c.errorFor('strength'), 'Strength cannot be negative');
    });

    test('validate fails when end date before start date', () {
      final c = MedicineFormController(api);
      c.setName('Test');
      c.setStartDate(DateTime(2026, 6, 1));
      c.setEndDate(DateTime(2026, 5, 1));
      expect(c.validate(), isFalse);
      expect(c.errorFor('endDate'), 'End date must not be before the start date');
    });

    test('toJson includes all fields with nulls for empty', () {
      final c = MedicineFormController(api);
      c.setName('Metformin');
      c.setGenericName('   ');
      c.setForm('Tablet');
      c.setStrength('500');
      c.setStrengthUnit('mg');
      c.setNotes('   ');
      c.setStatus(MedicineStatus.paused);
      c.setStartDate(DateTime(2026, 1, 1));
      c.setEndDate(DateTime(2026, 12, 31));

      final json = c.toJson();

      expect(json['name'], 'Metformin');
      expect(json['genericName'], isNull);
      expect(json['form'], 'Tablet');
      expect(json['strength'], 500);
      expect(json['strengthUnit'], 'mg');
      expect(json['notes'], isNull);
      expect(json['status'], 'PAUSED');
      expect(json['startDate'], '2026-01-01');
      expect(json['endDate'], '2026-12-31');
    });

    test('edit mode pre-fills from medicine', () {
      final med = Medicine(
        id: 'med-1',
        name: 'Aspirin',
        genericName: 'ASA',
        form: 'Tablet',
        strength: 100,
        strengthUnit: 'mg',
        notes: 'Daily',
        status: MedicineStatus.completed,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 6, 30),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final c = MedicineFormController(api, medicine: med);

      expect(c.name, 'Aspirin');
      expect(c.genericName, 'ASA');
      expect(c.form, 'Tablet');
      expect(c.strength, '100');
      expect(c.strengthUnit, 'mg');
      expect(c.notes, 'Daily');
      expect(c.status, MedicineStatus.completed);
      expect(c.startDate, DateTime(2026, 1, 1));
      expect(c.endDate, DateTime(2026, 6, 30));
    });

    test('save calls create on new medicine', () async {
      final c = MedicineFormController(api);
      c.setName('New Med');
      final saved = await c.save();
      expect(saved.id, 'new-med');
      expect(saved.name, 'New Med');
    });
  });

  group('ScheduleFormController', () {
    late _FakeMedicinesApiClient api;

    setUp(() {
      api = _FakeMedicinesApiClient(
        httpClient: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://test',
      );
    });

    test('validate fails for DAILY with no times', () {
      final c = ScheduleFormController(api, medicineId: 'med-1');
      c.setScheduleType(ScheduleType.daily);
      expect(c.validate(), isFalse);
      expect(c.errorFor('times'), 'At least one time is required');
    });

    test('validate fails for WEEKLY with no days', () {
      final c = ScheduleFormController(api, medicineId: 'med-1');
      c.setScheduleType(ScheduleType.weekly);
      c.setTimes(['08:00']);
      expect(c.validate(), isFalse);
      expect(c.errorFor('daysOfWeek'), 'At least one day is required');
    });

    test('validate passes for AS_NEEDED with no times/days', () {
      final c = ScheduleFormController(api, medicineId: 'med-1');
      c.setScheduleType(ScheduleType.asNeeded);
      c.setDoseAmount('10');
      c.setDoseUnit('mg');
      expect(c.validate(), isTrue);
    });

    test('toJson sends empty times for AS_NEEDED', () {
      final c = ScheduleFormController(api, medicineId: 'med-1');
      c.setScheduleType(ScheduleType.asNeeded);
      c.setTimes(['08:00']);
      c.setDaysOfWeek([1, 2]);
      c.setDoseAmount('500');
      c.setDoseUnit('mg');
      c.setStartDate(DateTime(2026, 1, 1));

      final json = c.toJson();

      expect(json['scheduleType'], 'AS_NEEDED');
      expect(json['times'], []);
      expect(json['daysOfWeek'], isEmpty);
      expect(json['doseAmount'], 500);
      expect(json['doseUnit'], 'mg');
      expect(json['startDate'], '2026-01-01');
    });

    test('toJson maps days to MONDAY etc strings', () {
      final c = ScheduleFormController(api, medicineId: 'med-1');
      c.setScheduleType(ScheduleType.weekly);
      c.setTimes(['09:00']);
      c.setDaysOfWeek([1, 3, 5]);

      final json = c.toJson();

      expect(json['daysOfWeek'], ['MONDAY', 'WEDNESDAY', 'FRIDAY']);
    });

    test('validate fails when end date before start date', () {
      final c = ScheduleFormController(api, medicineId: 'med-1');
      c.setScheduleType(ScheduleType.daily);
      c.setTimes(['08:00']);
      c.setStartDate(DateTime(2026, 6, 1));
      c.setEndDate(DateTime(2026, 5, 1));
      expect(c.validate(), isFalse);
      expect(c.errorFor('endDate'), 'End date must not be before the start date');
    });

    test('save calls create when no schedule', () async {
      final c = ScheduleFormController(api, medicineId: 'med-1');
      c.setScheduleType(ScheduleType.daily);
      c.setTimes(['08:00']);
      final saved = await c.save();
      expect(saved.id, 'new-sched');
    });

    test('edit mode pre-fills from schedule', () {
      final sched = Schedule(
        id: 'sched-1',
        medicineId: 'med-1',
        scheduleType: ScheduleType.weekly,
        times: ['09:00', '21:00'],
        daysOfWeek: [1, 5],
        doseAmount: 250,
        doseUnit: 'mg',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 9, 30),
        active: false,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final c = ScheduleFormController(api, medicineId: 'med-1', schedule: sched);

      expect(c.scheduleType, ScheduleType.weekly);
      expect(c.times, ['09:00', '21:00']);
      expect(c.daysOfWeek, [1, 5]);
      expect(c.doseAmount, '250');
      expect(c.doseUnit, 'mg');
      expect(c.active, isFalse);
      expect(c.startDate, DateTime(2026, 3, 1));
      expect(c.endDate, DateTime(2026, 9, 30));
    });
  });

  group('RefillFormController', () {
    late _FakeMedicinesApiClient api;

    setUp(() {
      api = _FakeMedicinesApiClient(
        httpClient: MockClient((_) async => http.Response('', 200)),
        baseUrl: 'http://test',
      );
    });

    test('validate fails for missing refill date', () {
      final c = RefillFormController(api, medicineId: 'med-1');
      c.setQuantity('30');
      expect(c.validate(), isFalse);
      expect(c.errorFor('refillDate'), 'Refill date is required');
    });

    test('validate fails for future refill date', () {
      final c = RefillFormController(api, medicineId: 'med-1');
      c.setRefillDate(DateTime.now().add(const Duration(days: 1)));
      c.setQuantity('30');
      expect(c.validate(), isFalse);
      expect(c.errorFor('refillDate'), 'Refill date cannot be in the future');
    });

    test('validate fails for zero quantity', () {
      final c = RefillFormController(api, medicineId: 'med-1');
      c.setRefillDate(DateTime.now());
      c.setQuantity('0');
      expect(c.validate(), isFalse);
      expect(c.errorFor('quantity'), 'Quantity must be greater than zero');
    });

    test('validate fails for negative remaining', () {
      final c = RefillFormController(api, medicineId: 'med-1');
      c.setRefillDate(DateTime.now());
      c.setQuantity('30');
      c.setRemainingQuantity('-5');
      expect(c.validate(), isFalse);
      expect(c.errorFor('remainingQuantity'), 'Remaining quantity cannot be negative');
    });

    test('toJson includes all fields', () {
      final c = RefillFormController(api, medicineId: 'med-1');
      c.setRefillDate(DateTime(2026, 1, 15));
      c.setQuantity('60');
      c.setRemainingQuantity('60');
      c.setNotes('Pharmacy');

      final json = c.toJson();

      expect(json['refillDate'], '2026-01-15');
      expect(json['quantity'], 60);
      expect(json['remainingQuantity'], 60);
      expect(json['notes'], 'Pharmacy');
    });

    test('save calls create on new refill', () async {
      final c = RefillFormController(api, medicineId: 'med-1');
      c.setRefillDate(DateTime.now());
      c.setQuantity('30');
      final saved = await c.save();
      expect(saved.id, 'new-refill');
    });

    test('edit mode pre-fills from refill', () {
      final refill = Refill(
        id: 'refill-1',
        medicineId: 'med-1',
        refillDate: DateTime(2026, 1, 15),
        quantity: 60,
        remainingQuantity: 50,
        notes: 'CVS',
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );
      final c = RefillFormController(api, medicineId: 'med-1', refill: refill);

      expect(c.refillDate, DateTime(2026, 1, 15));
      expect(c.quantity, '60');
      expect(c.remainingQuantity, '50');
      expect(c.notes, 'CVS');
    });
  });
}