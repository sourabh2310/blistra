import 'dart:io';
import 'dart:typed_data';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/documents/models/document.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';

/// Repository for document operations, backed by the shared [ApiClient].
class DocumentsRepository {
  final ApiClient _api;

  DocumentsRepository(this._api);

  /// List documents with optional filters
  Future<DocumentPage> list({
    DocumentCategory? category,
    DateTime? from,
    DateTime? to,
    int page = 0,
    int size = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'size': '$size',
      if (category != null) 'category': category.value,
      // Backend expects zone-less LocalDateTime (ISO.DATE_TIME, no Z/millis).
      if (from != null) 'from': _localDateTime(from),
      if (to != null) 'to': _localDateTime(to),
    };

    final json = await _api.get('/api/v1/documents', query: query);
    return DocumentPage.fromJson(json);
  }

  /// Get document metadata by ID
  Future<AppDocument> get(String id) async {
    final json = await _api.get('/api/v1/documents/$id');
    return AppDocument.fromJson(json);
  }

  /// Download document content as bytes
  Future<Uint8List> download(String id) async {
    return _api.getBytes('/api/v1/documents/$id/content');
  }

  /// Upload a new document with progress callback
  Future<AppDocument> upload({
    required PlatformFile file,
    required DocumentCategory category,
    String? description,
    void Function(double progress)? onProgress,
  }) async {
    // file_picker on mobile often returns path-only (bytes == null) unless
    // withData: true was used. Fall back to reading the file from disk.
    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) {
      throw ArgumentError.value(file, 'file', 'No file bytes to upload');
    }
    final multipartFile = http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: file.name,
      contentType: MediaType.parse(_guessMimeType(file.name)),
    );

    final fields = {
      'category': category.value,
      if (description != null && description.isNotEmpty)
        'description': description,
    };

    final json = await _api.uploadMultipart(
      '/api/v1/documents',
      fields: fields,
      files: [multipartFile],
      onProgress: onProgress,
    );
    return AppDocument.fromJson(json);
  }

  /// Update document metadata
  Future<AppDocument> update(
    String id, {
    DocumentCategory? category,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (category != null) body['category'] = category.value;
    if (description != null) body['description'] = description;

    final json = await _api.patch('/api/v1/documents/$id', body: body);
    return AppDocument.fromJson(json);
  }

  /// Delete a document
  Future<void> delete(String id) async {
    await _api.delete('/api/v1/documents/$id');
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

  /// Backend `LocalDateTime` wire format: yyyy-MM-ddTHH:mm:ss (no zone).
  static String _localDateTime(DateTime value) {
    final local = value.toLocal();
    return DateFormat("yyyy-MM-dd'T'HH:mm:ss").format(local);
  }
}
