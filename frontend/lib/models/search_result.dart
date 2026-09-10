class SearchResult {
  final String type;
  final String module;
  final String id;
  final String title;
  final String? subtitle;
  final DateTime timestamp;
  final String route;

  SearchResult({
    required this.type,
    required this.module,
    required this.id,
    required this.title,
    this.subtitle,
    required this.timestamp,
    required this.route,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      type: json['type'] as String,
      module: json['module'] as String,
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      route: json['route'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'module': module,
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp.toIso8601String(),
      'route': route,
    };
  }
}

class SearchResponse {
  final List<SearchResult> results;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;
  final bool partial;

  SearchResponse({
    required this.results,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
    required this.partial,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      results: (json['results'] as List<dynamic>?)
              ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      page: json['page'] as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
      last: json['last'] as bool? ?? true,
      partial: json['partial'] as bool? ?? false,
    );
  }
}