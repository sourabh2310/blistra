/// State controller for the Medicines Today view.
library;

import 'package:flutter/foundation.dart';

import '../data/medicines_api_client.dart';
import '../models/medicine_enums.dart';
import '../models/today_doses.dart';
import '../util/dates.dart';

class MedicineTodayController extends ChangeNotifier {
  MedicineTodayController(this._api);

  final MedicinesApiClient _api;

  MedicineToday? _today;
  bool _loading = false;
  Object? _error;

  /// Medicine id currently recording, to prevent accidental double taps.
  String? _recordingKey;
  Object? _recordError;

  MedicineToday? get today => _today;
  bool get isLoading => _loading;
  Object? get error => _error;
  Object? get recordError => _recordError;

  bool isRecording(ExpectedDose dose) =>
      _recordingKey == _key(dose.medicineId, dose.scheduledAt);

  static String _key(String medicineId, DateTime scheduledAt) =>
      '$medicineId@${scheduledAt.toIso8601String()}';

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _today = await _api.getTodayDoses(
        offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );
    } on Object catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Records an explicit "take now" for a pending slot. The slot instant is
  /// sent as scheduledAt (with its schedule id) so the backend matches the
  /// record to this occurrence and rejects accidental duplicates with 409.
  /// Viewing details never records; only this explicit action does.
  Future<bool> takeDose(ExpectedDose dose) async {
    if (!dose.isPending || dose.scheduledAt.isAfter(DateTime.now())) {
      return false;
    }
    final String key = _key(dose.medicineId, dose.scheduledAt);
    if (_recordingKey != null) return false;
    _recordingKey = key;
    _recordError = null;
    notifyListeners();
    try {
      await _api.recordDose(dose.medicineId, {
        'status': DoseStatus.taken.name.toUpperCase(),
        'scheduledAt': toOffsetIso(dose.scheduledAt),
        if (dose.scheduleId != null) 'scheduleId': dose.scheduleId,
      });
      await refresh();
      return true;
    } on Object catch (e) {
      _recordError = e;
      notifyListeners();
      return false;
    } finally {
      _recordingKey = null;
      notifyListeners();
    }
  }

  void clearRecordError() {
    _recordError = null;
    notifyListeners();
  }
}
