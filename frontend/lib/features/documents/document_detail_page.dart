import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../app/app_scope.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/page_header.dart';

import 'package:frontend/features/documents/models/document.dart';
import 'package:frontend/features/documents/providers/documents_provider.dart';
import 'widgets/document_visuals.dart';

/// Document detail (detail template): preview, metadata, recategorise,
/// edit, delete, and open/download pinned at the bottom.
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

  /// The latest copy from the provider, so edits show without reopening.
  AppDocument _current(DocumentsProvider provider) {
    for (final d in provider.documents) {
      if (d.id == widget.document.id) return d;
    }
    return widget.document;
  }

  @override
  void initState() {
    super.initState();
    if (widget.document.isImage) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = context.read<DocumentsProvider>();
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
    final auth = AppScope.of(context).authState;
    final session = auth.sessionGeneration;
    bool active() =>
        mounted && auth.isAuthenticated && session == auth.sessionGeneration;
    setState(() => _isDownloading = true);
    try {
      final repo = context.read<DocumentsProvider>();
      final bytes = await repo.download(widget.document.id);
      if (!active()) return;

      // Save to temp file
      final dir = await getTemporaryDirectory();
      if (!active()) return;
      final cache = Directory('${dir.path}/blistra-document-previews');
      await cache.create(recursive: true);
      if (!active()) return;
      final fileName = widget.document.originalFilename
          .split(RegExp(r'[/\\]'))
          .last;
      final file = File('${cache.path}/${widget.document.id}-$fileName');
      await file.writeAsBytes(bytes);
      if (!active()) {
        if (await file.exists()) await file.delete();
        return;
      }

      // Open with system app
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }

      if (mounted) showAppMessage(context, 'Opening document...');
    } catch (e) {
      if (mounted) showAppMessage(context, 'Failed to open: $e', error: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _save({DocumentCategory? category, String? description}) async {
    try {
      await context.read<DocumentsProvider>().update(
            widget.document.id,
            category: category,
            description: description,
          );
      if (mounted) showAppMessage(context, 'Document updated');
    } catch (e) {
      if (mounted) showAppMessage(context, 'Failed to update: $e', error: true);
    }
  }

  Future<void> _showEditDialog() async {
    final doc = _current(context.read<DocumentsProvider>());
    final categoryController = ValueNotifier<DocumentCategory>(doc.category);
    final descriptionController = TextEditingController(
      text: doc.description ?? '',
    );

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
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: DocumentCategory.values
                        .map(
                          (c) =>
                              DropdownMenuItem(value: c, child: Text(c.label)),
                        )
                        .toList(),
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
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
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
      await _save(
        category: result['category'],
        description:
            result['description'].isEmpty ? null : result['description'],
      );
    }
  }

  /// Bottom sheet of categories; saves only the category.
  Future<void> _recategorise(AppDocument doc) async {
    final picked = await showModalBottomSheet<DocumentCategory>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colors = BlistraColors.resolve(context);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(kPageGutter, 0, kPageGutter, 12),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Category', style: BlistraText.serif(20, colors.text)),
              ),
              GlassList(
                children: [
                  for (final c in DocumentCategory.values)
                    GlassRow(
                      leading: IconWell(
                        categoryIcon(c),
                        color: categoryColor(context, c),
                      ),
                      title: c.label,
                      trailing: c == doc.category
                          ? Icon(Icons.check_rounded, color: colors.accentText)
                          : null,
                      onTap: () => Navigator.pop(context, c),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && picked != doc.category && mounted) {
      await _save(category: picked);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await confirmAction(
      context,
      title: 'Delete Document',
      message:
          'Are you sure you want to delete "${widget.document.originalFilename}"? This cannot be undone.',
    );

    if (confirmed && mounted) {
      try {
        final provider = context.read<DocumentsProvider>();
        await provider.delete(widget.document.id);
        if (mounted) {
          Navigator.pop(context, true); // Return to list with refresh signal
          showAppMessage(context, 'Document deleted');
        }
      } catch (e) {
        if (mounted) {
          showAppMessage(context, 'Failed to delete: $e', error: true);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final doc = _current(context.watch<DocumentsProvider>());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            BlistraPageHeader(
              eyebrow: 'Document',
              title: doc.originalFilename,
              subtitle: '${doc.category.label} · ${doc.formattedSize} · '
                  'added ${doc.formattedDate}',
              showAvatar: false,
              actions: [
                GlassIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit metadata',
                  onTap: _showEditDialog,
                ),
                _DeleteMenu(onDelete: _confirmDelete),
              ],
            ),
            const SizedBox(height: 14),
            PagePad(_preview(doc)),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Details'),
            PagePad(GlassList(
              children: [
                GlassRow(
                  leading: IconWell(
                    categoryIcon(doc.category),
                    color: categoryColor(context, doc.category),
                  ),
                  title: doc.category.label,
                  subtitle: 'Category · tap to change',
                  trailing: const RowMeta('›'),
                  onTap: () => _recategorise(doc),
                ),
                GlassRow(
                  leading: const IconWell(Icons.notes_rounded),
                  title: doc.description ?? 'No description',
                  titleColor: doc.description == null ? colors.muted : null,
                  subtitle: 'Description',
                  trailing: const RowMeta('›'),
                  onTap: _showEditDialog,
                ),
              ],
            )),
            const SizedBox(height: 24),
            const SectionHeader(title: 'File'),
            PagePad(GlassList(
              children: [
                _InfoRow(label: 'Filename', value: doc.originalFilename),
                _InfoRow(label: 'Type', value: doc.contentType),
                _InfoRow(label: 'Size', value: doc.formattedSize),
                _InfoRow(label: 'Created', value: doc.formattedDate),
                _InfoRow(
                  label: 'Modified',
                  value: DateFormat('MMM d, yyyy HH:mm').format(doc.updatedAt),
                ),
              ],
            )),
          ],
        ),
      ),
      bottomNavigationBar: StickyActionBar(
        label: doc.isImage ? 'Download / Save Image' : 'Open Document',
        busy: _isDownloading,
        onPressed: _downloadAndOpen,
      ),
    );
  }

  Widget _preview(AppDocument doc) {
    final colors = BlistraColors.resolve(context);
    if (doc.isImage) {
      return GlassCard(
        padding: EdgeInsets.zero,
        radius: 22,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              size: 40, color: colors.danger),
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: colors.muted),
                          ),
                          const SizedBox(height: 10),
                          Pill('Retry', onTap: _loadImage),
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
                      : Center(
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 40, color: colors.muted),
                        ),
        ),
      );
    }
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          FileTypeBadge(
            document: doc,
            width: double.infinity,
            height: 110,
            fontSize: 18,
          ),
          const SizedBox(height: 12),
          Text(
            doc.isPdf
                ? 'PDF preview is not available in-app. Tap "Open Document" to view with your system PDF viewer.'
                : 'Preview is not available in-app. Tap "Open Document" to view it with another app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.4, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// Header "⋯" menu holding Delete.
class _DeleteMenu extends StatelessWidget {
  const _DeleteMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return PopupMenuButton<String>(
      tooltip: 'More',
      padding: EdgeInsets.zero,
      onSelected: (_) => onDelete(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: colors.danger)),
        ),
      ],
      child: const GlassIconButton(
        icon: Icons.more_horiz_rounded,
        tooltip: null,
        onTap: null,
      ),
    );
  }
}

/// Label on the left, value on the right.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 12, color: colors.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
