/// A page of results from a paginated backend endpoint (`PageResponse<T>`).
class PageResult<T> {
  PageResult({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final content = json['content'];
    return PageResult(
      content: content is List
          ? content
              .whereType<Map<String, dynamic>>()
              .map(fromJson)
              .toList()
          : <T>[],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
    );
  }

  final List<T> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  bool get isEmpty => content.isEmpty;

  bool get hasMore => page + 1 < totalPages;
}