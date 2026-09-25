/// Form controller for creating/editing a refill record with validation.
library;

import '../data/medicines_api_client.dart';
import '../models/refill.dart';
import '../util/dates.dart';
import '../util/numbers.dart';

class RefillFormController {
  RefillFormController(this._api, {required this.medicineId, Refill? refill})
      : _refill = refill {
    if (refill != null) {
      _refillDate = refill.refillDate;
      _quantity = trimNumber(refill.quantity);
      _remainingQuantity = refill.remainingQuantity == null
          ? ''
          : trimNumber(refill.remainingQuantity!);
      _notes = refill.notes ?? '';
    }
  }

  final MedicinesApiClient _api;
  final String medicineId;
  final Refill? _refill;

  final Map<String, String> _fieldErrors = {};

  DateTime? _refillDate;
  String _quantity = '';
  String _remainingQuantity = '';
  String _notes = '';

  DateTime? get refillDate => _refillDate;
  String get quantity => _quantity;
  String get remainingQuantity => _remainingQuantity;
  String get notes => _notes;

  String? errorFor(String field) => _fieldErrors[field];
  bool get hasErrors => _fieldErrors.isNotEmpty;

  void setRefillDate(DateTime? v) => _refillDate = v;
  void setQuantity(String v) => _quantity = v;
  void setRemainingQuantity(String v) => _remainingQuantity = v;
  void setNotes(String v) => _notes = v;

  bool validate() {
    _fieldErrors.clear();

    if (_refillDate == null) {
      _fieldErrors['refillDate'] = 'Refill date is required';
    } else if (_refillDate!.isAfter(DateTime.now())) {
      _fieldErrors['refillDate'] = 'Refill date cannot be in the future';
    }

    if (_quantity.trim().isEmpty) {
      _fieldErrors['quantity'] = 'Quantity is required';
    } else {
      final double? val = double.tryParse(_quantity.trim());
      if (val == null || val <= 0) {
        _fieldErrors['quantity'] = 'Quantity must be greater than zero';
      }
    }

    if (_remainingQuantity.isNotEmpty) {
      final double? val = double.tryParse(_remainingQuantity.trim());
      if (val == null || val < 0) {
        _fieldErrors['remainingQuantity'] = 'Remaining quantity cannot be negative';
      }
    }

    if (_notes.trim().length > 500) {
      _fieldErrors['notes'] = 'Notes must be at most 500 characters';
    }

    return _fieldErrors.isEmpty;
  }

  Map<String, dynamic> toJson() {
    return {
      'refillDate': isoDateOrNull(_refillDate),
      'quantity': double.tryParse(_quantity.trim()),
      'remainingQuantity': _remainingQuantity.trim().isEmpty
          ? null
          : double.tryParse(_remainingQuantity.trim()),
      'notes': _notes.trim().isEmpty ? null : _notes.trim(),
    };
  }

  Future<Refill> save() async {
    if (!validate()) {
      throw Exception('Please fix the highlighted fields');
    }
    if (_refill == null) {
      return _api.createRefill(medicineId, toJson());
    } else {
      return _api.updateRefill(medicineId, _refill.id, toJson());
    }
  }
}