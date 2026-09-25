/// Client for the backend unified search (`GET /api/v1/search`).
///
/// All results are scoped server-side to the authenticated user.
library;

import '../../core/api/api_client.dart';

class SearchResultItem {
  SearchResultItem({
    required this.type,
    required this.module,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final String type;
  final String module;
  final String id;
  final String title;
  final String subtitle;
  final String route;

  factory SearchResultItem.fromJson(Map<String, dynamic> json) {
    return SearchResultItem(
      type: (json['type'] ?? '').toString(),
      module: (json['module'] ?? '').toString(),
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      route: (json['route'] ?? '').toString(),
    );
  }
}

class SearchApi {
  SearchApi(this._client);

  final ApiClient _client;

  Future<List<SearchResultItem>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final json = await _client.get('/api/v1/search', query: {'q': q});
    final results = json['results'];
    if (results is! List) return const [];
    return [
      for (final item in results)
        if (item is Map<String, dynamic>) SearchResultItem.fromJson(item),
    ];
  }
}
