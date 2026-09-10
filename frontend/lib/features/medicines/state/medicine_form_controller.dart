/// Form controller for creating/editing a medicine with validation.
library;

import '../data/medicines_api_client.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../util/dates.dart';

class MedicineFormController {
  MedicineFormController(this._api, {Medicine? medicine}) : _medicine = medicine {
    if (medicine != null) {
      _name = medicine.name;
      _genericName = medicine.genericName ?? '';
      _form = medicine.form ?? '';
      _strength = medicine.strength?.toString() ?? '';
      _strengthUnit = medicine.strengthUnit ?? '';
      _notes = medicine.notes ?? '';
      _status = medicine.status;
      _startDate = medicine.startDate;
      _endDate = medicine.endDate;
    }
  }

  final MedicinesApiClient _api;
  final Medicine? _medicine;

  final Map<String, String> _fieldErrors = {};

  String _name = '';
  String _genericName = '';
  String _form = '';
  String _strength = '';
  String _strengthUnit = '';
  String _notes = '';
  MedicineStatus _status = MedicineStatus.active;
  DateTime? _startDate;
  DateTime? _endDate;

  String get name => _name;
  String get genericName => _genericName;
  String get form => _form;
  String get strength => _strength;
  String get strengthUnit => _strengthUnit;
  String get notes => _notes;
  MedicineStatus get status => _status;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  String? errorFor(String field) => _fieldErrors[field];
  bool get hasErrors => _fieldErrors.isNotEmpty;

  void setName(String v) => _name = v;
  void setGenericName(String v) => _genericName = v;
  void setForm(String v) => _form = v;
  void setStrength(String v) => _strength = v;
  void setStrengthUnit(String v) => _strengthUnit = v;
  void setNotes(String v) => _notes = v;
  void setStatus(MedicineStatus v) => _status = v;
  void setStartDate(DateTime? v) => _startDate = v;
  void setEndDate(DateTime? v) => _endDate = v;

  bool validate() {
    _fieldErrors.clear();

    if (_name.trim().isEmpty) {
      _fieldErrors['name'] = 'Name is required';
    }
    if (_name.trim().length > 100) {
      _fieldErrors['name'] = 'Name must be at most 100 characters';
    }
    if (_genericName.trim().length > 100) {
      _fieldErrors['genericName'] = 'Generic name must be at most 100 characters';
    }
    if (_form.trim().length > 50) {
      _fieldErrors['form'] = 'Form must be at most 50 characters';
    }
    if (_strength.isNotEmpty) {
      final double? val = double.tryParse(_strength.trim());
      if (val == null || val < 0) {
        _fieldErrors['strength'] = 'Strength cannot be negative';
      }
    }
    if (_strengthUnit.trim().length > 25) {
      _fieldErrors['strengthUnit'] = 'Strength unit must be at most 25 characters';
    }
    if (_notes.trim().length > 1000) {
      _fieldErrors['notes'] = 'Notes must be at most 1000 characters';
    }
    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      _fieldErrors['endDate'] = 'End date must not be before the start date';
    }

    return _fieldErrors.isEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': _name.trim(),
      'genericName': _genericName.trim().isEmpty ? null : _genericName.trim(),
      'form': _form.trim().isEmpty ? null : _form.trim(),
      'strength': _strength.trim().isEmpty ? null : double.tryParse(_strength.trim()),
      'strengthUnit': _strengthUnit.trim().isEmpty ? null : _strengthUnit.trim(),
      'notes': _notes.trim().isEmpty ? null : _notes.trim(),
      'status': _status.name.toUpperCase(),
      'startDate': isoDateOrNull(_startDate),
      'endDate': isoDateOrNull(_endDate),
    };
  }

  Future<Medicine> save() async {
    if (!validate()) {
      throw Exception('Please fix the highlighted fields');
    }
    if (_medicine == null) {
      return _api.createMedicine(toJson());
    } else {
      return _api.updateMedicine(_medicine!.id, toJson());
    }
  }
}