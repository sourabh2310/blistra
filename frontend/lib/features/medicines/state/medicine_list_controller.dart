/// State controller for the medicines list page.
library;

import 'package:flutter/foundation.dart';

import '../data/medicines_api_client.dart';
import '../models/medicine.dart';
import '../models/medicine_enums.dart';
import '../models/page.dart';

class MedicineListController extends ChangeNotifier {
  MedicineListController(this._api);

  final MedicinesApiClient _api;

  final List<Medicine> _medicines = [];
  MedicineStatus? _statusFilter;
  bool _loading = false;
  bool _loadingMore = false;
  Object? _error;
  bool _hasMore = true;
  int _nextPage = 0;
  static const int _pageSize = 50;

  List<Medicine> get medicines => List.unmodifiable(_medicines);
  MedicineStatus? get statusFilter => _statusFilter;
  bool get isLoading => _loading;
  bool get isLoadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  Object? get error => _error;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    _nextPage = 0;
    _hasMore = true;
    notifyListeners();

    try {
      final Page<Medicine> page = await _api.listMedicines(
        status: _statusFilter,
        page: 0,
        size: _pageSize,
      );
      _medicines
        ..clear()
        ..addAll(page.content);
      _nextPage = page.last ? _nextPage : 1;
      _hasMore = !page.last;
    } on Object catch (e) {
      _error = e;
      _medicines.clear();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _loadingMore || _loading) return;
    _loadingMore = true;
    notifyListeners();

    try {
      final Page<Medicine> page = await _api.listMedicines(
        status: _statusFilter,
        page: _nextPage,
        size: _pageSize,
      );
      _medicines.addAll(page.content);
      _nextPage = page.last ? _nextPage : _nextPage + 1;
      _hasMore = !page.last;
    } on Object catch (e) {
      _error = e;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<void> setStatusFilter(MedicineStatus? status) async {
    if (status == _statusFilter) return;
    _statusFilter = status;
    _medicines.clear();
    await refresh();
  }

  Future<void> archive(String id) async {
    await _api.archiveMedicine(id);
    _medicines.removeWhere((m) => m.id == id);
    notifyListeners();
  }

  bool isArchived(Medicine m) => m.status == MedicineStatus.archived;
}