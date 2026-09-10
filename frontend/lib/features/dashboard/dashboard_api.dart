/// Typed client for the Dashboard REST API.
library;

import '../../core/api/api_client.dart';
import 'models/dashboard_response.dart';

class DashboardApi {
  DashboardApi({required this.apiClient});

  final ApiClient apiClient;

  Future<DashboardResponse> getDashboard({
    DateTime? date,
    int offsetMinutes = 0,
  }) async {
    final query = <String, String>{
      'offsetMinutes': '$offsetMinutes',
    };
    if (date != null) {
      query['date'] = _dateOnly(date);
    }

    final data = await apiClient.get('/api/v1/dashboard', query: query);
    return DashboardResponse.fromJson(data as Map<String, dynamic>);
  }

  static String _dateOnly(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}