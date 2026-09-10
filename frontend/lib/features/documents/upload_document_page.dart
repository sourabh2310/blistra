import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/features/documents/models/document.dart';
import 'package:frontend/features/documents/providers/documents_provider.dart';

class UploadDocumentPage extends StatefulWidget {
  const UploadDocumentPage({super.key});

  @override
  State<UploadDocumentPage> createState() => _UploadDocumentPageState();
}

class _UploadDocumentPageState extends State<UploadDocumentPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  PlatformFile? _selectedFile;
  DocumentCategory _selectedCategory = DocumentCategory.other;
  bool _isUploading = false;
  double _progress = 0.0;
  String? _error;

  static const _maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const _allowedExtensions = {'pdf', 'jpg', 'jpeg', 'png'};

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions.toList(),
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Client-side validation
        if (file.size > _maxFileSize) {
          setState(() => _error = 'File exceeds maximum size of 10 MB');
          return;
        }

        final ext = file.extension?.toLowerCase() ?? '';
        if (!_allowedExtensions.contains(ext)) {
          setState(() => _error = 'Unsupported file type. Allowed: PDF, JPG, PNG');
          return;
        }

        setState(() {
          _selectedFile = file;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to pick file: $e');
    }
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      setState(() => _error = 'Please select a file');
      return;
    }

    setState(() {
      _isUploading = true;
      _progress = 0.0;
      _error = null;
    });

    try {
      final provider = context.read<DocumentsProvider>();
      await provider.upload(
        file: _selectedFile!,
        category: _selectedCategory,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Document'),
        leading: _isUploading ? null : IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // File selection
              _FileSelectionCard(
                file: _selectedFile,
                onPick: _pickFile,
                onClear: () => setState(() => _selectedFile = null),
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<DocumentCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                items: DocumentCategory.values.map((cat) => DropdownMenuItem(
                      value: cat,
                      child: Text(cat.label),
                    )).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'Add a note about this document...',
                ),
                maxLines: 3,
                maxLength: 1000,
              ),
              const SizedBox(height: 24),

              // Error display
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: colorScheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Upload progress
              if (_isUploading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uploading... ${(_progress * 100).toStringAsFixed(0)}%',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _progress,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ],

              // Action buttons
              if (!_isUploading) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.attach_file),
                        label: _selectedFile == null
                            ? const Text('Choose File')
                            : Text('Change (${_selectedFile!.name})'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _selectedFile == null ? null : _upload,
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('Upload'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // Help text
              const SizedBox(height: 24),
              Text(
                'Supported formats: PDF, JPEG, PNG\nMaximum size: 10 MB',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileSelectionCard extends StatelessWidget {
  final PlatformFile? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _FileSelectionCard({
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (file == null) {
      return InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(
              color: colorScheme.outline,
              style: BorderStyle.solid,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                size: 48,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                'Tap to select a document',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'PDF, JPEG, PNG • Max 10 MB',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _fileIcon(file!),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file!.name,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatSize(file!.size),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: colorScheme.error),
              onPressed: onClear,
              tooltip: 'Remove file',
            ),
          ],
        ),
      );
    }

  Widget _fileIcon(PlatformFile file) {
    final ext = file.extension?.toLowerCase() ?? '';
    if (ext == 'pdf') {
      return const Icon(Icons.picture_as_pdf, size: 24);
    } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
      return const Icon(Icons.image, size: 24);
    }
    return const Icon(Icons.insert_drive_file, size: 24);
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}