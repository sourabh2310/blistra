/// Live contract test: drives every module's real Flutter API client (the
/// same payload builders the forms use) against a running backend, through
/// create -> read -> update -> delete.
///
/// Skipped unless pointed at a disposable dev backend:
///   BLISTRA_E2E_URL=http://127.0.0.1:8080 \
///   BLISTRA_E2E_TOKEN=TOKEN_FOR_FIRST_TEST_USER \
///   BLISTRA_E2E_TOKEN2=TOKEN_FOR_SECOND_TEST_USER \
///   BLISTRA_E2E_USERNAME2=SECOND_TEST_USERNAME \
///   flutter test test/e2e/contract_test.dart
@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/dashboard/dashboard_api.dart';
import 'package:frontend/features/diet/diet_api.dart';
import 'package:frontend/features/diet/models/diet_profile.dart';
import 'package:frontend/features/diet/models/meal.dart';
import 'package:frontend/features/documents/models/document.dart';
import 'package:frontend/features/documents/repositories/documents_repository.dart';
import 'package:frontend/features/finance/finance_api.dart';
import 'package:frontend/features/finance/models.dart';
import 'package:frontend/features/habits/habits_api.dart';
import 'package:frontend/features/habits/models.dart';
import 'package:frontend/features/health/health_api.dart';
import 'package:frontend/features/health/health_models.dart';
import 'package:frontend/features/medicines/data/medicines_api_client.dart';
import 'package:frontend/features/medicines/models/medicine_enums.dart';
import 'package:frontend/features/medicines/state/medicine_form_controller.dart';
import 'package:frontend/features/medicines/state/refill_form_controller.dart';
import 'package:frontend/features/medicines/state/schedule_form_controller.dart';
import 'package:frontend/features/medicines/util/dates.dart';
import 'package:frontend/features/planner/planner_api.dart';
import 'package:frontend/features/preferences/preferences_api.dart';

final String _url = Platform.environment['BLISTRA_E2E_URL'] ?? '';
final String _token = Platform.environment['BLISTRA_E2E_TOKEN'] ?? '';
final String _token2 = Platform.environment['BLISTRA_E2E_TOKEN2'] ?? '';
final String _username2 = Platform.environment['BLISTRA_E2E_USERNAME2'] ?? '';

ApiClient _client([String? token]) =>
    ApiClient(baseUrl: _url)..token = token ?? _token;

void main() {
  final skip = _url.isEmpty || _token.isEmpty
      ? 'Set BLISTRA_E2E_URL and BLISTRA_E2E_TOKEN'
      : null;
  final now = DateTime.now();

  test('planner: lists, tasks and events', () async {
    final api = PlannerApi(_client());
    final list = await api.createTaskList(name: 'E2E list');
    final task = await api.createTask(
      title: 'E2E task',
      dueDate: now,
      taskListId: list.id,
    );
    expect((await api.getTask(task.id)).title, 'E2E task');
    await api.updateTask(task.id, title: 'E2E task edited');
    expect((await api.completeTask(task.id)).id, task.id);
    await api.reopenTask(task.id);
    final event = await api.createEvent(
      title: 'E2E event',
      startAt: now.add(const Duration(hours: 1)),
      endAt: now.add(const Duration(hours: 2)),
      location: 'Office',
    );
    await api.updateEvent(
      event.id,
      title: 'E2E event moved',
      startAt: now.add(const Duration(hours: 3)),
      endAt: now.add(const Duration(hours: 4)),
    );
    await api.today();
    await api.schedule(date: now, days: 7);
    await api.deleteEvent(event.id);
    await api.deleteTask(task.id);
    await api.deleteTaskList(list.id);
  }, skip: skip);

  test('diet: profile, meals with items, water, summary', () async {
    final api = HttpDietApi(_client());
    await api.upsertProfile(DietProfile(notes: 'E2E'));
    final meal = await api.createMeal(
      title: 'E2E lunch',
      mealType: 'LUNCH',
      consumedAt: now,
      items: [
        MealItem(name: 'Rice', quantity: 1, unit: 'bowl', caloriesKcal: 200),
      ],
    );
    final item = await api.addMealItem(
      meal.id,
      MealItem(name: 'Dal', caloriesKcal: 150),
    );
    await api.updateMealItem(
      meal.id,
      item.id!,
      MealItem(name: 'Dal tadka', caloriesKcal: 180),
    );
    await api.updateMeal(
      meal.id,
      title: 'E2E late lunch',
      mealType: 'LUNCH',
      consumedAt: now,
    );
    expect((await api.getMeal(meal.id)).title, 'E2E late lunch');
    await api.deleteMealItem(meal.id, item.id!);
    final water = await api.createWater(
      amount: 250,
      unit: 'ml',
      consumedAt: now,
    );
    await api.updateWater(water.id, amount: 1, unit: 'glass', consumedAt: now);
    final summary = await api.dailySummary(
      now,
      offsetMinutes: now.timeZoneOffset.inMinutes,
    );
    expect(summary, isNotNull);
    await api.deleteWater(water.id);
    await api.deleteMeal(meal.id);
  }, skip: skip);

  test('habits: create, schedule, complete, stats, archive', () async {
    final api = HabitsApi(apiClient: _client());
    final habit = await api.createHabit(
      name: 'E2E read',
      type: HabitType.duration,
      targetMinutes: 20,
    );
    await api.updateHabit(
      habit.id,
      name: 'E2E reading',
      type: HabitType.duration,
      targetMinutes: 30,
    );
    await api.upsertSchedule(
      habit.id,
      frequency: HabitFrequency.weekly,
      daysOfWeek: ['MONDAY', 'THURSDAY'],
    );
    await api.upsertSchedule(habit.id, frequency: HabitFrequency.daily);
    await api.recordCompletion(habit.id, completedOn: now, durationMinutes: 25);
    await api.fetchTodayHabits();
    await api.fetchStatistics(habit.id);
    await api.removeCompletion(habit.id, now);
    await api.archiveHabit(habit.id);
  }, skip: skip);

  test('health: profile and every record type', () async {
    final api = HealthApi(_client());
    await api.saveProfile(
      HealthProfileInput(
        heightCm: 172,
        bloodType: BloodType.oPositive,
        dateOfBirth: DateTime(1995, 5, 5),
      ),
    );
    final m = await api.createMeasurement(
      MeasurementInput(
        type: MeasurementType.bloodPressure,
        measuredAt: now,
        value: 120,
        valueDiastolic: 80,
        unit: 'mmHg',
      ),
    );
    await api.updateMeasurement(
      m.id,
      MeasurementInput(
        type: MeasurementType.bloodPressure,
        measuredAt: now,
        value: 118,
        valueDiastolic: 78,
        unit: 'mmHg',
      ),
    );
    final w = await api.createMeasurement(
      MeasurementInput(
        type: MeasurementType.weight,
        measuredAt: now,
        value: 70.5,
        unit: 'kg',
      ),
    );
    final sleep = await api.createSleep(
      SleepInput(
        startedAt: now.subtract(const Duration(hours: 8)),
        endedAt: now,
        rating: 4,
      ),
    );
    await api.updateSleep(
      sleep.id,
      SleepInput(
        startedAt: now.subtract(const Duration(hours: 7)),
        endedAt: now,
        rating: 5,
      ),
    );
    final act = await api.createActivity(
      ActivityInput(
        type: ActivityType.walking,
        performedAt: now,
        durationMinutes: 30,
        distanceKm: 2.5,
      ),
    );
    await api.updateActivity(
      act.id,
      ActivityInput(
        type: ActivityType.running,
        performedAt: now,
        durationMinutes: 20,
      ),
    );
    final log = await api.createLog(
      LogInput(title: 'Headache', observedAt: now, severity: Severity.mild),
    );
    await api.updateLog(
      log.id,
      LogInput(title: 'Headache', observedAt: now, severity: Severity.moderate),
    );
    final ev = await api.createEvent(
      EventInput(type: EventType.checkup, title: 'Annual', occurredAt: now),
    );
    await api.updateEvent(
      ev.id,
      EventInput(
        type: EventType.checkup,
        title: 'Annual checkup',
        occurredAt: now,
      ),
    );
    final appt = await api.createAppointment(
      AppointmentInput(
        title: 'Dentist',
        scheduledAt: now.add(const Duration(days: 3)),
        location: 'Clinic',
      ),
    );
    await api.updateAppointment(
      appt.id,
      AppointmentInput(
        title: 'Dentist',
        scheduledAt: now.add(const Duration(days: 4)),
      ),
    );
    for (final del in [
      () => api.deleteMeasurement(m.id),
      () => api.deleteMeasurement(w.id),
      () => api.deleteSleep(sleep.id),
      () => api.deleteActivity(act.id),
      () => api.deleteLog(log.id),
      () => api.deleteEvent(ev.id),
      () => api.deleteAppointment(appt.id),
    ]) {
      await del();
    }
  }, skip: skip);

  test('medicines: form controllers, doses, refills, today', () async {
    final api = MedicinesApiClient(baseUrl: _url, tokenProvider: () => _token);
    final form = MedicineFormController(api)
      ..setName('E2E Vitamin D')
      ..setForm('tablet')
      ..setStrength('1000')
      ..setStrengthUnit('IU');
    final medicine = await form.save();
    final edit = MedicineFormController(api, medicine: medicine)
      ..setNotes('With breakfast');
    await edit.save();

    final schedule = ScheduleFormController(api, medicineId: medicine.id)
      ..setScheduleType(ScheduleType.customDays)
      ..setTimes(['08:00', '20:00'])
      ..setDaysOfWeek([1, 3, 5])
      ..setDoseAmount('1')
      ..setDoseUnit('tablet');
    final saved = await schedule.save();

    final dose = await api.recordDose(medicine.id, {
      'status': DoseStatus.taken.name.toUpperCase(),
      'scheduledAt': nowOffsetIso(),
      'scheduleId': saved.id,
    });
    await api.updateDose(medicine.id, dose.id, {
      'status': DoseStatus.skipped.name.toUpperCase(),
    });
    await api.getTodayDoses(
      date: now,
      offsetMinutes: now.timeZoneOffset.inMinutes,
    );

    final refill = RefillFormController(api, medicineId: medicine.id)
      ..setRefillDate(now)
      ..setQuantity('30');
    final r = await refill.save();
    await api.deleteRefill(medicine.id, r.id);
    await api.deleteDose(medicine.id, dose.id);
    await api.deleteSchedule(medicine.id, saved.id);
    await api.archiveMedicine(medicine.id);
  }, skip: skip);

  test('finance: personal expense, friend request, split, settle', () async {
    final api = FinanceApi(apiClient: _client());
    final personal = await api.createExpense(
      ExpenseDraft(
        description: 'E2E coffee',
        category: ExpenseCategory.food,
        amount: '120',
        currency: 'INR',
        spentOn: now,
      ),
    );
    await api.updateExpense(
      personal.id,
      ExpenseDraft(
        description: 'E2E coffee + cake',
        category: ExpenseCategory.food,
        amount: '180',
        currency: 'INR',
        spentOn: now,
      ),
    );
    expect((await api.overview(now)).currencies, isNotEmpty);

    if (_token2.isNotEmpty && _username2.isNotEmpty) {
      final api2 = FinanceApi(apiClient: _client(_token2));
      final me = (await api.friends()).me!;
      final friend = (await api2.friends()).me!;
      await api.addFriend('@$_username2');
      final request = (await api2.friends()).incoming.firstWhere(
        (r) => r.user.id == me.id,
      );
      await api2.acceptRequest(request.id);

      final split = await api.createExpense(
        ExpenseDraft(
          description: 'E2E dinner',
          category: ExpenseCategory.food,
          amount: '900',
          currency: 'INR',
          spentOn: now,
          splitType: SplitType.equal,
          participants: [(me.id, null), (friend.id, null)],
        ),
      );
      expect(split.myBalance.toPlainString(), '450.0000');
      final bobView = (await api2.friends()).friends.firstWhere(
        (f) => f.user.id == me.id,
      );
      expect(bobView.balances.single.amount.isNegative, isTrue);
      final payment = await api2.settleUp(
        friendId: me.id,
        iPaid: true,
        amount: '450',
        currency: 'INR',
      );
      expect(payment.status, 'PENDING');
      expect((await api.friendDetail(friend.id)).friend.settled, isFalse);
      await api.decideSettlement(payment.id, confirmed: true);
      final detail = await api.friendDetail(friend.id);
      expect(detail.friend.settled, isTrue);
      for (final s in detail.settlements) {
        if (s.editable) await api.deleteSettlement(s.id);
      }
      // Confirmed payment history stays in this disposable test database.
      await api.deleteExpense(split.id);
      await api.removeFriend(friend.id);
    }
    await api.deleteExpense(personal.id);
  }, skip: skip);

  test(
    'finance: invite, join a trip, split and confirm group payment',
    () async {
      if (_token2.isEmpty || _username2.isEmpty) return;
      final api = FinanceApi(apiClient: _client()),
          api2 = FinanceApi(apiClient: _client(_token2));
      final me = (await api.friends()).me!, friend = (await api2.friends()).me!;
      final group = await api.createGroup('Contract trip', 'INR');
      await api.inviteToGroup(group.id, _username2);
      expect(
        (await api2.groups()).any((g) => g.id == group.id && g.invited),
        isTrue,
      );
      await api2.acceptGroup(group.id);
      expect((await api.group(group.id)).accepted.length, 2);
      await api.createExpense(
        ExpenseDraft(
          groupId: group.id,
          description: 'Trip hotel',
          category: ExpenseCategory.travel,
          amount: '900',
          currency: 'INR',
          spentOn: now,
          splitType: SplitType.equal,
          participants: [(me.id, null), (friend.id, null)],
        ),
      );
      final payment = await api2.settleUp(
        groupId: group.id,
        friendId: me.id,
        iPaid: true,
        amount: '450',
        currency: 'INR',
      );
      expect((await api.group(group.id)).balances, isNotEmpty);
      await api.decideSettlement(payment.id, confirmed: true);
      expect((await api.group(group.id)).balances, isEmpty);
      expect((await api.history(groupId: group.id)).length, 3);
    },
    skip: skip,
  );

  test('documents: upload, edit, download, delete', () async {
    final repo = DocumentsRepository(_client());
    final pdf = utf8.encode(
      '%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n',
    );
    final doc = await repo.upload(
      file: PlatformFile(name: 'e2e-report.pdf', size: pdf.length, bytes: pdf),
      category: DocumentCategory.medical,
      description: 'E2E upload',
    );
    await repo.update(
      doc.id,
      category: DocumentCategory.personal,
      description: 'E2E edited',
    );
    expect((await repo.download(doc.id)).length, pdf.length);
    await repo.delete(doc.id);
  }, skip: skip);

  test('home, preferences and search', () async {
    final client = _client();
    await DashboardApi(apiClient: client)
        .getDashboard(date: now, offsetMinutes: now.timeZoneOffset.inMinutes);
    final prefs = PreferencesApi(client);
    final current = await prefs.getPreferences();
    await prefs.updatePreferences(
      bottomNav: current.bottomNav,
      homeWidgets: current.homeWidgets,
    );
    await client.get('/api/v1/search', query: {'q': 'e2e'});
  }, skip: skip);
}
