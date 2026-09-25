import 'package:flutter/foundation.dart';
import 'package:frontend/features/documents/models/document.dart';
import 'package:frontend/features/documents/repositories/documents_repository.dart';
import 'package:file_picker/file_picker.dart';

/// State management for documents feature using ChangeNotifier
class DocumentsProvider extends ChangeNotifier {
  final DocumentsRepository _repository;

  DocumentsProvider(this._repository);

  // State
  List<AppDocument> _documents = [];
  DocumentPage? _page;
  DocumentCategory? _selectedCategory;
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;

  // Getters
  List<AppDocument> get documents => List.unmodifiable(_documents);
  DocumentPage? get page => _page;
  DocumentCategory? get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasMore => _page?.hasNext ?? false;

  /// Load first page of documents
  Future<void> load({bool refresh = false}) async {
    if (_isLoading && !refresh) return;
    _setLoading(true);
    _clearError();

    try {
      final page = await _repository.list(
        category: _selectedCategory,
        page: 0,
        size: 20,
      );
      _page = page;
      _documents = page.content;
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<AppDocument?> getById(String id) async {
    try {
      return await _repository.get(id);
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Load next page (pagination)
  Future<void> loadMore() async {
    if (_isLoading || !hasMore) return;
    _setLoading(true);

    try {
      final nextPage = (_page?.page ?? 0) + 1;
      final page = await _repository.list(
        category: _selectedCategory,
        page: nextPage,
        size: 20,
      );
      _page = page;
      _documents.addAll(page.content);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  /// Change category filter
  Future<void> setCategoryFilter(DocumentCategory? category) async {
    _selectedCategory = category;
    await load(refresh: true);
  }

  /// Upload a new document
  Future<AppDocument?> upload({
    required PlatformFile file,
    required DocumentCategory category,
    String? description,
  }) async {
    _setUploading(true);
    _uploadProgress = 0.0;
    _clearError();
    notifyListeners();

    try {
      final doc = await _repository.upload(
        file: file,
        category: category,
        description: description,
        onProgress: (p) {
          _uploadProgress = p;
          notifyListeners();
        },
      );
      _documents.insert(0, doc);
      if (_page != null) {
        _page = DocumentPage(
          content: _documents,
          page: _page!.page,
          size: _page!.size,
          totalElements: _page!.totalElements + 1,
          totalPages: _page!.totalPages,
        );
      }
      _setUploading(false);
      _uploadProgress = 0.0;
      notifyListeners();
      return doc;
    } catch (e) {
      _setError(e.toString());
      _setUploading(false);
      _uploadProgress = 0.0;
      notifyListeners();
      return null;
    }
  }

  /// Update document metadata
  Future<void> update(String id, {DocumentCategory? category, String? description}) async {
    try {
      final updated = await _repository.update(id, category: category, description: description);
      final index = _documents.indexWhere((d) => d.id == id);
      if (index != -1) {
        _documents[index] = updated;
        notifyListeners();
      }
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Delete a document
  Future<void> delete(String id) async {
    try {
      await _repository.delete(id);
      _documents.removeWhere((d) => d.id == id);
      if (_page != null) {
        _page = DocumentPage(
          content: _documents,
          page: _page!.page,
          size: _page!.size,
          totalElements: _page!.totalElements - 1,
          totalPages: _page!.totalPages,
        );
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setUploading(bool value) {
    _isUploading = value;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }
}