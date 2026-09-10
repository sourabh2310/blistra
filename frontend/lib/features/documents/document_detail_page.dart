import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:blistra/features/documents/models/document.dart';
import 'package:blistra/features/documents/providers/documents_provider.dart';
import 'package:blistra/features/documents/repositories/documents_repository.dart';

class DocumentDetailPage extends StatefulWidget {
  final AppDocument document;

  const DocumentDetailPage({super.key, required this.document});

  @override
  State<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends State<DocumentDetailPage> {
  bool _isLoading = false;
  bool _isDownloading = false;
  Uint8List? _imageBytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.document.isImage) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() => _isLoading = true);
    try {
      final repo = context.read<DocumentsRepository>();
      final bytes = await repo.download(widget.document.id);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load preview: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _downloadAndOpen() async {
    setState(() => _isDownloading = true);
    try {
      final repo = context.read<DocumentsRepository>();
      final bytes = await repo.download(widget.document.id);

      // Save to temp file
      final dir = await getTemporaryDirectory();
      final fileName = widget.document.originalFilename;
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      // Open with system app
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening document...')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _showEditDialog() async {
    final categoryController = ValueNotifier<DocumentCategory>(widget.document.category);
    final descriptionController = TextEditingController(text: widget.document.description ?? '');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Metadata'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<DocumentCategory>(
                valueListenable: categoryController,
                builder: (context, category, _) {
                  return DropdownButtonFormField<DocumentCategory>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: DocumentCategory.values.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c.label),
                        )).toList(),
                    onChanged: (v) => categoryController.value = v!,
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional description',
                ),
                maxLines: 3,
                maxLength: 1000,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'category': categoryController.value,
              'description': descriptionController.text.trim(),
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final provider = context.read<DocumentsProvider>();
        await provider.update(
          widget.document.id,
          category: result['category'],
          description: result['description'].isEmpty ? null : result['description'],
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document updated')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Are you sure you want to delete "${widget.document.originalFilename}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final provider = context.read<DocumentsProvider>();
        await provider.delete(widget.document.id);
        if (mounted) {
          Navigator.pop(context, true); // Return to list with refresh signal
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final doc = widget.document;

    return Scaffold(
      appBar: AppBar(
        title: Text(doc.originalFilename, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showEditDialog,
            tooltip: 'Edit metadata',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _confirmDelete,
            color: colorScheme.error,
            tooltip: 'Delete',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview section
            if (doc.isImage) ...[
              _buildImagePreview(),
              const SizedBox(height: 16),
            ] else if (doc.isPdf) ...[
              _buildPdfPlaceholder(),
              const SizedBox(height: 16),
            ],

            // Metadata
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Details', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _DetailRow(label: 'Filename', value: doc.originalFilename),
                    _DetailRow(label: 'Type', value: doc.contentType),
                    _DetailRow(label: 'Size', value: doc.formattedSize),
                    _DetailRow(label: 'Category', value: doc.category.label),
                    if (doc.description != null)
                      _DetailRow(label: 'Description', value: doc.description!),
                    _DetailRow(label: 'Created', value: doc.formattedDate),
                    _DetailRow(label: 'Modified', value: DateFormat('MMM d, yyyy HH:mm').format(doc.updatedAt)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Actions
            if (doc.isPdf) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isDownloading ? null : _downloadAndOpen,
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download),
                  label: Text(_isDownloading ? 'Opening...' : 'Open Document'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ] else if (doc.isImage) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _downloadAndOpen,
                  icon: const Icon(Icons.download),
                  label: const Text('Download / Save Image'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                ),
              ),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 48, color: theme.colorScheme.error),
                        const SizedBox(height: 8),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadImage,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _imageBytes != null
                    ? Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      )
                    : const Center(child: Icon(Icons.image_not_supported, size: 48)),
      ),
    );
  }

  Widget _buildPdfPlaceholder() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.picture_as_pdf,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'PDF Document',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'PDF preview is not available in-app. Tap "Open Document" to view with your system PDF viewer.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}