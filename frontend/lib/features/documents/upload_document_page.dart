import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/features/documents/models/document.dart';
import 'package:frontend/features/documents/providers/documents_provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/page_header.dart';
import 'widgets/document_visuals.dart';

/// Upload form (form template): file, category chips, description, and
/// Upload pinned at the bottom.
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
  String? _error;

  static const _maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const _maxDescription = 1000;
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
          setState(
            () => _error = 'Unsupported file type. Allowed: PDF, JPG, PNG',
          );
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
      _error = null;
    });

    try {
      final provider = context.read<DocumentsProvider>();
      final uploaded = await provider.upload(
        file: _selectedFile!,
        category: _selectedCategory,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (uploaded == null) {
        if (mounted) {
          setState(() {
            _error = provider.error ?? 'Upload failed. Please try again.';
            _isUploading = false;
          });
        }
        return;
      }

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
    final colors = BlistraColors.resolve(context);
    final progress = context.watch<DocumentsProvider>().uploadProgress;

    return PopScope(
      canPop: !_isUploading,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const BlistraPageHeader(
                  eyebrow: 'Add Document',
                  title: 'What are you adding?',
                  subtitle: 'PDF, JPEG or PNG · up to 10 MB',
                  showAvatar: false,
                ),
                const SizedBox(height: 16),
                PagePad(_FileField(
                  file: _selectedFile,
                  onPick: _isUploading ? null : _pickFile,
                  onClear: _isUploading
                      ? null
                      : () => setState(() => _selectedFile = null),
                )),
                PagePad(Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Text(
                    'CATEGORY',
                    style: BlistraText.caption(colors.muted),
                  ),
                )),
                PagePad(CategoryChips(
                  selected: _selectedCategory,
                  onSelected: _isUploading
                      ? null
                      : (c) => setState(() => _selectedCategory = c),
                )),
                const SizedBox(height: 14),
                PagePad(GlassTextField(
                  label: 'Description (optional)',
                  controller: _descriptionController,
                  hint: 'Add a note about this document...',
                  maxLines: 3,
                  enabled: !_isUploading,
                  validator: (v) => (v?.length ?? 0) > _maxDescription
                      ? 'Keep it under $_maxDescription characters'
                      : null,
                )),
                if (_error != null)
                  PagePad(GlassCard(
                    radius: 16,
                    padding: const EdgeInsets.all(14),
                    tint: colors.danger,
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: colors.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(fontSize: 12.5, color: colors.text),
                          ),
                        ),
                      ],
                    ),
                  )),
                if (_isUploading)
                  PagePad(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Uploading... ${(progress * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: colors.accentText,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ProgressLine(value: progress),
                      ],
                    ),
                    top: 14,
                  ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: StickyActionBar(
          label: 'Upload',
          busy: _isUploading,
          onPressed: _selectedFile == null ? null : _upload,
        ),
      ),
    );
  }
}

/// Glass file field: a prompt to pick, or the chosen file with a clear button.
class _FileField extends StatelessWidget {
  final PlatformFile? file;
  final VoidCallback? onPick;
  final VoidCallback? onClear;

  const _FileField({
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final picked = file;

    if (picked == null) {
      return FieldCard(
        label: 'File',
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              IconWell(Icons.upload_file_rounded, color: colors.accentText),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap to select a document',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.accentText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PDF, JPEG, PNG • Max 10 MB',
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return FieldCard(
      label: 'File',
      onTap: onPick,
      child: Row(
        children: [
          IconWell(_fileIcon(picked), color: colors.accentText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  picked.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatSize(picked.size)} · tap to change',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: colors.danger),
            onPressed: onClear,
            tooltip: 'Remove file',
          ),
        ],
      ),
    );
  }

  IconData _fileIcon(PlatformFile file) {
    final ext = file.extension?.toLowerCase() ?? '';
    if (ext == 'pdf') {
      return Icons.picture_as_pdf_outlined;
    } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
      return Icons.image_outlined;
    }
    return Icons.insert_drive_file_outlined;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
