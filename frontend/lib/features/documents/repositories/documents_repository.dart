import 'dart:convert';
import 'dart:typed_data';
import 'package:blistra/core/api/api_config.dart';
import 'package:blistra/features/documents/models/document.dart';
import 'package:file_picker/file_picker.dart';

/// Repository for document operations
class DocumentsRepository {
  final ApiConfig _api;

  DocumentsRepository(this._api);

  /// List documents with optional filters
  Future<DocumentPage> list({
    DocumentCategory? category,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'size': size,
    };
    if (category != null) query['category'] = category.value;
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();

    final response = await _api.get('/documents', query: query);
    _checkResponse(response);
    return DocumentPage.fromJson(jsonDecode(response.body));
  }

  /// Get document metadata by ID
  Future<AppDocument> get(String id) async {
    final response = await _api.get('/documents/$id');
    _checkResponse(response);
    return AppDocument.fromJson(jsonDecode(response.body));
  }

  /// Download document content as bytes
  Future<Uint8List> download(String id) async {
    final response = await _api.get('/documents/$id/content');
    if (response.statusCode != 200) {
      throw _apiError(response, 'Failed to download document');
    }
    return response.bodyBytes;
  }

  /// Upload a new document with progress callback
  Future<AppDocument> upload({
    required PlatformFile file,
    required DocumentCategory category,
    String? description,
    void Function(double progress)? onProgress,
  }) async {
    final multipartFile = ApiConfig.MultipartFile(
      fieldName: 'file',
      fileName: file.name,
      contentType: file.mimeType ?? _guessMimeType(file.name),
      bytes: file.bytes!,
    );

    final fields = {
      'category': category.value,
      if (description != null && description.isNotEmpty) 'description': description,
    };

    final streamed = await _api.uploadMultipart(
      '/documents',
      fields: fields,
      files: [multipartFile],
      onProgress: onProgress != null
          ? (sent, total) => onProgress(sent / total)
          : null,
    );

    final response = await http.Response.fromStream(streamed);
    _checkResponse(response);
    return AppDocument.fromJson(jsonDecode(response.body));
  }

  /// Update document metadata
  Future<AppDocument> update(String id, {
    DocumentCategory? category,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (category != null) body['category'] = category.value;
    if (description != null) body['description'] = description;

    final response = await _api.patch('/documents/$id', body: body);
    _checkResponse(response);
    return AppDocument.fromJson(jsonDecode(response.body));
  }

  /// Delete a document
  Future<void> delete(String id) async {
    final response = await _api.delete('/documents/$id');
    if (response.statusCode != 204) {
      throw _apiError(response, 'Failed to delete document');
    }
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    throw _apiError(response, 'Request failed');
  }

  Exception _apiError(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body);
      return Exception(data['message'] ?? '$fallback (${response.statusCode})');
    } catch (_) {
      return Exception('$fallback (${response.statusCode})');
    }
  }

  String _guessMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}