import 'package:intl/intl.dart';

/// Document category enum matching backend
enum DocumentCategory {
  medical('MEDICAL', 'Medical'),
  finance('FINANCE', 'Finance'),
  personal('PERSONAL', 'Personal'),
  insurance('INSURANCE', 'Insurance'),
  receipt('RECEIPT', 'Receipt'),
  prescription('PRESCRIPTION', 'Prescription'),
  report('REPORT', 'Report'),
  other('OTHER', 'Other');

  const DocumentCategory(this.value, this.label);
  final String value;
  final String label;

  static DocumentCategory fromValue(String value) {
    return DocumentCategory.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DocumentCategory.other,
    );
  }
}

/// Document model matching backend DocumentResponse
class AppDocument {
  final String id;
  final String originalFilename;
  final String contentType;
  final int fileSize;
  final DocumentCategory category;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  AppDocument({
    required this.id,
    required this.originalFilename,
    required this.contentType,
    required this.fileSize,
    required this.category,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AppDocument.fromJson(Map<String, dynamic> json) {
    return AppDocument(
      id: json['id'] as String,
      originalFilename: json['originalFilename'] as String,
      contentType: json['contentType'] as String,
      fileSize: json['fileSize'] as int,
      category: DocumentCategory.fromValue(json['category'] as String),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  /// Human-readable file size
  String get formattedSize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Whether this document is an image (previewable in-app)
  bool get isImage => contentType.startsWith('image/');

  /// Whether this document is a PDF
  bool get isPdf => contentType == 'application/pdf';

  String get formattedDate => DateFormat('MMM d, yyyy').format(createdAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppDocument && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Paginated document list response
class DocumentPage {
  final List<AppDocument> content;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;

  DocumentPage({
    required this.content,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  factory DocumentPage.fromJson(Map<String, dynamic> json) {
    return DocumentPage(
      content: (json['content'] as List)
          .map((e) => AppDocument.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      size: json['size'] as int,
      totalElements: json['totalElements'] as int,
      totalPages: json['totalPages'] as int,
    );
  }

  bool get hasNext => page < totalPages - 1;
  bool get hasPrevious => page > 0;
}