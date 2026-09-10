/// Generic paged response matching the backend's PageResponse contract.
class Page<T> {
  const Page({
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

  bool get isEmpty => content.isEmpty;
  bool get isNotEmpty => content.isNotEmpty;

  factory Page.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final List<Object?> rawContent =
        (json['content'] as List?)?.whereType<Object?>().toList() ?? const [];
    return Page<T>(
      content: rawContent.map((e) => parseItem(e as Map<String, dynamic>)).toList(),
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      totalElements: (json['totalElements'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      last: json['last'] == true,
    );
  }
}