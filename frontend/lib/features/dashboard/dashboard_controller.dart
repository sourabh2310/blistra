/// Application state for the Dashboard feature.
library;

import 'package:flutter/foundation.dart';

import '../../core/api/api_exception.dart';
import 'dashboard_api.dart';
import 'models/dashboard_response.dart';

enum DashboardLoadStatus { idle, loading, ready, error }

class DashboardController extends ChangeNotifier {
  DashboardController({required this.api});

  final DashboardApi api;

  DashboardLoadStatus _status = DashboardLoadStatus.idle;
  String? _errorMessage;
  DashboardResponse? _dashboard;
  bool _refreshing = false;

  DashboardLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage;
  DashboardResponse? get dashboard => _dashboard;

  bool get isLoading => _status == DashboardLoadStatus.loading;
  bool get hasData => _dashboard != null;
  bool get refreshing => _refreshing;

  Future<void> loadDashboard({
    DateTime? date,
    int offsetMinutes = 0,
  }) async {
    _status = DashboardLoadStatus.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      _dashboard = await api.getDashboard(
        date: date,
        offsetMinutes: offsetMinutes,
      );
      _status = DashboardLoadStatus.ready;
    } on ApiException catch (error) {
      _errorMessage = error.toString();
      _status = DashboardLoadStatus.error;
    }
    notifyListeners();
  }

  Future<void> refresh({
    DateTime? date,
    int offsetMinutes = 0,
  }) async {
    _refreshing = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _dashboard = await api.getDashboard(
        date: date,
        offsetMinutes: offsetMinutes,
      );
      if (_status == DashboardLoadStatus.error) {
        _status = DashboardLoadStatus.ready;
      }
    } on ApiException catch (error) {
      _errorMessage = error.toString();
      if (_dashboard == null) {
        _status = DashboardLoadStatus.error;
      }
    } catch (_) {
      _errorMessage = 'Failed to refresh dashboard. Please try again.';
      if (_dashboard == null) {
        _status = DashboardLoadStatus.error;
      }
    }
    _refreshing = false;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}