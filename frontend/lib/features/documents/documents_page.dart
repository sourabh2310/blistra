import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/features/documents/models/document.dart';
import 'package:frontend/features/documents/providers/documents_provider.dart';
import 'package:frontend/features/documents/upload_document_page.dart';
import 'package:frontend/features/documents/document_detail_page.dart';
import 'package:frontend/core/auth/auth_state.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/blistra_ui.dart';
import '../../core/widgets/design_system.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/page_header.dart';
import 'widgets/document_visuals.dart';

/// Documents home: search first, category chips, recent files as cards,
/// then the full list. Upload is the primary action.
class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DocumentsProvider>().load();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<DocumentsProvider>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DocumentsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () => provider.load(refresh: true),
              child: ListView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 120),
                children: [
                  BlistraPageHeader(
                    eyebrow: 'Documents',
                    title: 'Your files',
                    actions: [
                      GlassIconButton(
                        icon: Icons.upload_rounded,
                        tooltip: 'Upload document',
                        onTap: provider.isUploading ? null : _openUpload,
                      ),
                      _MoreMenu(onSignOut: _logout),
                    ],
                  ),
                  PagePad(
                    DocumentSearchField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                    top: 8,
                  ),
                  const SizedBox(height: 12),
                  _categoryChips(provider),
                  ..._buildBody(provider),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: provider.isUploading ? null : _openUpload,
            tooltip: 'Upload document',
            child: provider.isUploading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: BlistraColors.resolve(context).onAccent,
                    ),
                  )
                : const Icon(Icons.upload_rounded),
          ),
        );
      },
    );
  }

  /// "All" plus one chip per category. Only the selected chip shows a count:
  /// the backend reports a total for the active filter only.
  Widget _categoryChips(DocumentsProvider provider) {
    final selected = provider.selectedCategory;
    final total = provider.isLoading ? null : provider.page?.totalElements;
    String label(String name, bool on) =>
        on && total != null ? '$name $total' : name;
    return ChipRow(
      labels: [
        label('All', selected == null),
        for (final c in DocumentCategory.values) label(c.label, selected == c),
      ],
      icons: [
        Icons.folder_outlined,
        for (final c in DocumentCategory.values) categoryIcon(c),
      ],
      selected: selected == null
          ? 0
          : DocumentCategory.values.indexOf(selected) + 1,
      onSelected: (i) => provider.setCategoryFilter(
        i == 0 ? null : DocumentCategory.values[i - 1],
      ),
    );
  }

  List<Widget> _buildBody(DocumentsProvider provider) {
    if (provider.isLoading && provider.documents.isEmpty) {
      return const [SizedBox(height: 20), SkeletonLoader(rows: 4)];
    }

    if (provider.hasError && provider.documents.isEmpty) {
      return [
        const SizedBox(height: 20),
        PagePad(_ErrorCard(
          message: provider.error ?? 'Unknown error',
          onRetry: () => provider.load(refresh: true),
        )),
      ];
    }

    if (provider.documents.isEmpty) {
      final cat = provider.selectedCategory;
      return [
        const SizedBox(height: 20),
        PagePad(EmptyCard(
          message: cat == null
              ? 'No documents yet. Upload your first one.'
              : 'No ${cat.label.toLowerCase()} documents yet.',
          action: 'Upload',
          onAction: provider.isUploading ? null : _openUpload,
        )),
      ];
    }

    final footer = [
      if (provider.hasMore)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
    ];

    if (_query.isNotEmpty) {
      final words = _query.toLowerCase().split(RegExp(r'\s+'));
      final matches = provider.documents.where((d) {
        final text = '${d.originalFilename} ${d.description ?? ''} '
                '${d.category.label}'
            .toLowerCase();
        return words.every(text.contains);
      }).toList();
      return [
        const SizedBox(height: 24),
        SectionHeader(title: 'Results', actionLabel: '${matches.length}'),
        PagePad(matches.isEmpty
            ? EmptyCard(message: 'No documents match "$_query".')
            : _list(matches)),
        ...footer,
      ];
    }

    final recent = [...provider.documents]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final total = provider.page?.totalElements ?? provider.documents.length;
    return [
      const SizedBox(height: 24),
      const SectionHeader(title: 'Recent'),
      PagePad(_RecentGrid(
        documents: recent.take(4).toList(),
        onOpen: _openDetail,
      )),
      const SizedBox(height: 24),
      SectionHeader(title: 'All', actionLabel: '$total'),
      PagePad(_list(provider.documents)),
      ...footer,
    ];
  }

  Widget _list(List<AppDocument> documents) {
    return GlassList(
      children: [
        for (final doc in documents)
          GlassRow(
            leading: FileTypeBadge(document: doc),
            title: doc.originalFilename,
            subtitle:
                '${doc.category.label} · ${doc.formattedSize} · ${doc.formattedDate}',
            onTap: () => _openDetail(doc),
            trailing: _RowMenu(onDelete: () => _confirmDelete(doc)),
          ),
      ],
    );
  }

  void _openUpload() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const UploadDocumentPage()));
  }

  void _openDetail(AppDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DocumentDetailPage(document: doc)),
    );
  }

  Future<void> _confirmDelete(AppDocument doc) async {
    final provider = context.read<DocumentsProvider>();
    final confirmed = await confirmAction(
      context,
      title: 'Delete Document',
      message:
          'Are you sure you want to delete "${doc.originalFilename}"? This action cannot be undone.',
    );
    if (!confirmed) return;
    try {
      await provider.delete(doc.id);
      if (mounted) showAppMessage(context, 'Document deleted');
    } catch (e) {
      if (mounted) showAppMessage(context, 'Failed to delete: $e', error: true);
    }
  }

  Future<void> _logout() async {
    final auth = context.read<AuthState>();
    Navigator.of(context).popUntil((route) => route.isFirst);
    await auth.logout();
  }
}

/// Two-column grid of the newest files.
class _RecentGrid extends StatelessWidget {
  const _RecentGrid({required this.documents, required this.onOpen});

  final List<AppDocument> documents;
  final ValueChanged<AppDocument> onOpen;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < documents.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _RecentCard(document: documents[i], onOpen: onOpen)),
          const SizedBox(width: 10),
          Expanded(
            child: i + 1 < documents.length
                ? _RecentCard(document: documents[i + 1], onOpen: onOpen)
                : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return Column(children: rows);
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.document, required this.onOpen});

  final AppDocument document;
  final ValueChanged<AppDocument> onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(12),
      onTap: () => onOpen(document),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FileTypeBadge(
            document: document,
            width: double.infinity,
            height: 64,
            fontSize: 12,
          ),
          const SizedBox(height: 9),
          Text(
            document.originalFilename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${document.category.label} · ${document.formattedSize}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: colors.muted),
          ),
        ],
      ),
    );
  }
}

/// Trailing "⋯" on a list row.
class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: Icon(Icons.more_horiz_rounded, size: 20, color: colors.muted),
      onSelected: (_) => onDelete(),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: colors.danger)),
        ),
      ],
    );
  }
}

/// Header "⋯" menu holding Sign out.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.onSignOut});

  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      padding: EdgeInsets.zero,
      onSelected: (_) => onSignOut(),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'logout', child: Text('Sign out')),
      ],
      child: const GlassIconButton(
        icon: Icons.more_horiz_rounded,
        tooltip: null,
        onTap: null,
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Failed to load documents',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Pill('Retry', onTap: onRetry),
        ],
      ),
    );
  }
}
