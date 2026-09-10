import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../models/search_result.dart';
import '../../core/auth/auth_state.dart';

class SearchApi {
  final AuthState _authState;

  SearchApi({AuthState? authState}) : _authState = authState ?? AuthState(apiClient: throw UnsupportedError('AuthState required'));

  Future<SearchResponse> search({
    required String query,
    String? type,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final token = _authState.apiClient.token;
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/api/v1/search').replace(queryParameters: {
      'q': query,
      if (type != null) 'type': type,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'page': page.toString(),
      'size': size.toString(),
    });

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 401) {
      _authState.logout();
      throw Exception('Session expired. Please log in again.');
    }

    if (response.statusCode != 200) {
      throw Exception('Search failed: ${response.statusCode}');
    }

    return SearchResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}