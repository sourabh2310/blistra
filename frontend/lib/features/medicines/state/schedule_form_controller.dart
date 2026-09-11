/// Form controller for creating/editing a medication schedule with validation.
library;

import '../data/medicines_api_client.dart';
import '../models/medicine_enums.dart';
import '../models/schedule.dart';
import '../util/dates.dart';

class ScheduleFormController {
  ScheduleFormController(this._api, {this.medicineId, Schedule? schedule})
      : _schedule = schedule {
    if (schedule != null) {
      _scheduleType = schedule.scheduleType;
      _times = schedule.times;
      _daysOfWeek = schedule.daysOfWeek ?? const [];
      _doseAmount = schedule.doseAmount?.toString() ?? '';
      _doseUnit = schedule.doseUnit ?? '';
      _active = schedule.active;
      _startDate = schedule.startDate;
      _endDate = schedule.endDate;
    }
  }

  final MedicinesApiClient _api;
  final String? medicineId;
  final Schedule? _schedule;

  final Map<String, String> _fieldErrors = {};

  ScheduleType _scheduleType = ScheduleType.daily;
  List<String> _times = [];
  List<int> _daysOfWeek = [];
  String _doseAmount = '';
  String _doseUnit = '';
  bool _active = true;
  DateTime? _startDate;
  DateTime? _endDate;

  ScheduleType get scheduleType => _scheduleType;
  List<String> get times => List.unmodifiable(_times);
  List<int> get daysOfWeek => List.unmodifiable(_daysOfWeek);
  String get doseAmount => _doseAmount;
  String get doseUnit => _doseUnit;
  bool get active => _active;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  String? errorFor(String field) => _fieldErrors[field];
  bool get hasErrors => _fieldErrors.isNotEmpty;

  void setScheduleType(ScheduleType v) => _scheduleType = v;
  void setTimes(List<String> v) => _times = v;
  void setDaysOfWeek(List<int> v) => _daysOfWeek = v;
  void setDoseAmount(String v) => _doseAmount = v;
  void setDoseUnit(String v) => _doseUnit = v;
  void setActive(bool v) => _active = v;
  void setStartDate(DateTime? v) => _startDate = v;
  void setEndDate(DateTime? v) => _endDate = v;

  bool validate() {
    _fieldErrors.clear();

    if (_scheduleType.requiresTimes && _times.isEmpty) {
      _fieldErrors['times'] = 'At least one time is required';
    }
    if (_scheduleType.requiresDays && _daysOfWeek.isEmpty) {
      _fieldErrors['daysOfWeek'] = 'At least one day is required';
    }
    if (_doseAmount.isNotEmpty) {
      final double? val = double.tryParse(_doseAmount.trim());
      if (val == null || val < 0) {
        _fieldErrors['doseAmount'] = 'Dose amount cannot be negative';
      }
    }
    if (_doseUnit.trim().length > 25) {
      _fieldErrors['doseUnit'] = 'Dose unit must be at most 25 characters';
    }
    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      _fieldErrors['endDate'] = 'End date must not be before the start date';
    }

    return _fieldErrors.isEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'scheduleType': _scheduleType.wire,
      'times': _scheduleType == ScheduleType.asNeeded ? <String>[] : _times,
      'daysOfWeek': _daysOfWeek.map(_dayIndexToString).toList(),
      'doseAmount': _doseAmount.trim().isEmpty ? null : double.tryParse(_doseAmount.trim()),
      'doseUnit': _doseUnit.trim().isEmpty ? null : _doseUnit.trim(),
      'startDate': isoDateOrNull(_startDate),
      'endDate': isoDateOrNull(_endDate),
      'active': _active,
    };
  }

  static String _dayIndexToString(int index) {
    switch (index) {
      case 1:
        return 'MONDAY';
      case 2:
        return 'TUESDAY';
      case 3:
        return 'WEDNESDAY';
      case 4:
        return 'THURSDAY';
      case 5:
        return 'FRIDAY';
      case 6:
        return 'SATURDAY';
      case 7:
        return 'SUNDAY';
      default:
        return 'MONDAY';
    }
  }

  Future<Schedule> save() async {
    if (!validate()) {
      throw Exception('Please fix the highlighted fields');
    }
    if (_schedule == null) {
      if (medicineId == null) throw Exception('medicineId required for create');
      return _api.createSchedule(medicineId!, toJson());
    } else {
      return _api.updateSchedule(medicineId!, _schedule!.id, toJson());
    }
  }
}

extension on ScheduleType {
  bool get requiresTimes => this != ScheduleType.asNeeded;
  bool get requiresDays => this == ScheduleType.weekly || this == ScheduleType.customDays;
}