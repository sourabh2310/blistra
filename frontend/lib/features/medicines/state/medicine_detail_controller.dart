/// State controller for a medicine detail page.
library;

import 'package:flutter/foundation.dart';

import '../data/medicines_api_client.dart';
import '../models/dose_record.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../models/page.dart';
import '../models/refill.dart';
import '../models/schedule.dart';
import '../models/today_doses.dart';
import '../util/dates.dart';

class MedicineDetailController extends ChangeNotifier {
  MedicineDetailController(this._api, {required this.medicineId});

  final MedicinesApiClient _api;
  final String medicineId;

  Medicine? _medicine;
  List<Schedule> _schedules = [];
  List<DoseRecord> _recentDoses = [];
  List<Refill> _refills = [];
  List<ExpectedDose> _todaysDoses = [];

  bool _loading = true;
  bool _recordingDose = false;
  Object? _error;
  Object? _doseError;

  Medicine? get medicine => _medicine;
  List<Schedule> get schedules => List.unmodifiable(_schedules);
  List<DoseRecord> get recentDoses => List.unmodifiable(_recentDoses);
  List<Refill> get refills => List.unmodifiable(_refills);
  List<ExpectedDose> get todaysDoses => List.unmodifiable(_todaysDoses);
  bool get isLoading => _loading;
  bool get isRecordingDose => _recordingDose;
  Object? get error => _error;
  Object? get doseError => _doseError;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _medicine = await _api.getMedicine(medicineId);
      final results = await Future.wait([
        _api.listSchedules(medicineId),
        _api.listDoses(medicineId, page: 0, size: 20),
        _api.listRefills(medicineId),
      ]);
      _schedules = results[0] as List<Schedule>;
      _recentDoses = (results[1] as Page<DoseRecord>).content;
      _refills = results[2] as List<Refill>;
    } on Object catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
    await loadTodaysDoses();
  }

  /// Today's expected slots for this medicine only. Supplementary: a failure
  /// here never hides the medicine itself.
  Future<void> loadTodaysDoses() async {
    try {
      final MedicineToday today = await _api.getTodayDoses(
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
      _todaysDoses =
          today.doses.where((d) => d.medicineId == medicineId).toList();
      notifyListeners();
    } catch (_) {
      // Today's slots stay empty; core details and history still work.
    }
  }

  Future<void> recordDose({
    required DoseStatus status,
    DateTime? scheduledAt,
    String? scheduleId,
    String note = '',
  }) async {
    _recordingDose = true;
    _doseError = null;
    notifyListeners();

    try {
      await _api.recordDose(medicineId, {
        'status': status.name.toUpperCase(),
        // Backend expects OffsetDateTime — never send zone-less local ISO.
        'scheduledAt': scheduledAt != null ? toOffsetIso(scheduledAt) : nowOffsetIso(),
        if (scheduleId case final String id) 'scheduleId': id,
        if (note.isNotEmpty) 'note': note,
      });
      await _reloadRecentDoses();
      await loadTodaysDoses();
    } on Object catch (e) {
      _doseError = e;
    } finally {
      _recordingDose = false;
      notifyListeners();
    }
  }

  Future<void> _reloadRecentDoses() async {
    final page = await _api.listDoses(medicineId, page: 0, size: 20);
    _recentDoses = page.content;
    notifyListeners();
  }

  Future<void> reloadSchedules() async {
    _schedules = await _api.listSchedules(medicineId);
    notifyListeners();
  }

  Future<void> reloadRefills() async {
    _refills = await _api.listRefills(medicineId);
    notifyListeners();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _api.deleteSchedule(medicineId, scheduleId);
    await reloadSchedules();
  }

  Future<void> deleteRefill(String refillId) async {
    await _api.deleteRefill(medicineId, refillId);
    await reloadRefills();
  }

  Future<void> updateDose(String doseId, DoseStatus status) async {
    await _api.updateDose(medicineId, doseId, {'status': status.name.toUpperCase()});
    await _reloadRecentDoses();
    await loadTodaysDoses();
  }

  Future<void> deleteDose(String doseId) async {
    await _api.deleteDose(medicineId, doseId);
    await _reloadRecentDoses();
    await loadTodaysDoses();
  }

  Future<void> archive() async {
    await _api.archiveMedicine(medicineId);
    _medicine = await _api.getMedicine(medicineId);
    notifyListeners();
  }
}