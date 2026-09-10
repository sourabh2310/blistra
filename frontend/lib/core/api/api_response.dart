/// Generic pagination envelope shared by backend list endpoints.
///
/// Most backend modules return Spring-style pages:
/// `{content, page, size, totalElements, totalPages, last}`.
/// Features map `content` with their own `fromJson`.
library;

class PageResponse<T> {
  PageResponse({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
    required this.last,
  });

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
  final bool last;

  bool get hasNext => !last;

  factory PageResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final raw = json['content'];
    final List<T> items = raw is List
        ? raw
            .whereType<Map<String, dynamic>>()
            .map(fromJson)
            .toList(growable: false)
        : const [];
    return PageResponse(
      content: items,
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? items.length,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? items.length,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
      last: json['last'] as bool? ?? true,
    );
  }

  Map<String, String> nextQuery({int size = 20}) => {
        'page': '${page + 1}',
        'size': '$size',
      };
}
