/// Global search over the user's own data (backend `/api/v1/search`).
///
/// Results group by domain and open the owning detail screen via
/// [AppRoutes.resolveSearchRoute]. Module chips filter the groups and the
/// match is highlighted in the accent. Empty/error states are explicit;
/// nothing is ever fabricated. Recent searches are not stored, so none are
/// shown.
library;

import 'package:flutter/material.dart';

import '../../../core/routing/routes.dart';
import '../search_api.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.api,
    required this.onOpenRoute,
  });

  final SearchApi api;
  final void Function(String route) onOpenRoute;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<SearchResultItem> _results = const [];
  bool _searching = false;
  bool _searched = false;
  String? _error;

  /// Query the current results belong to, used for highlighting.
  String _resultQuery = '';

  /// Selected module chip; null shows every group.
  String? _module;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run([String? value]) async {
    final q = (value ?? _controller.text).trim();
    if (q.length < 2) {
      setState(() {
        _results = const [];
        _searched = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.api.search(q);
      if (!mounted) return;
      setState(() {
        _results = results;
        _resultQuery = q;
        _searched = true;
        if (_module != null && !results.any((r) => _groupLabel(r) == _module)) {
          _module = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const BlistraPageHeader(
              eyebrow: 'Search',
              title: 'Find anything',
              showAvatar: false,
            ),
            PagePad(
              Semantics(
                label: 'Search your data',
                textField: true,
                child: GlassCard(
                  radius: 16,
                  padding: const EdgeInsets.only(left: 14, right: 4),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 19, color: colors.muted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          cursorColor: colors.accentText,
                          style: TextStyle(fontSize: 14, color: colors.text),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            hintText: 'What are you looking for?',
                            hintStyle:
                                TextStyle(fontSize: 13, color: colors.muted),
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 13),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: _run,
                        ),
                      ),
                      if (_controller.text.isNotEmpty)
                        IconButton(
                          tooltip: 'Clear',
                          icon: Icon(Icons.close_rounded,
                              size: 18, color: colors.muted),
                          onPressed: () {
                            _controller.clear();
                            _run('');
                          },
                        ),
                    ],
                  ),
                ),
              ),
              top: 10,
            ),
            SizedBox(
              height: 14,
              child: _searching
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                          kPageGutter + 6, 6, kPageGutter + 6, 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: colors.accentText,
                          backgroundColor: colors.inkAt(0.08),
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return _Empty(
        icon: Icons.cloud_off_outlined,
        title: 'Search failed',
        message: _error!,
        actionLabel: 'Retry',
        onAction: () => _run(),
      );
    }
    if (!_searched) {
      return const _Empty(
        icon: Icons.search,
        title: 'Search your life',
        message: 'Tasks, medicines, meals, habits, finance and more.',
      );
    }
    if (_results.isEmpty) {
      return _Empty(
        icon: Icons.search_off_outlined,
        title: 'No results',
        message: 'Nothing matches "${_controller.text.trim()}".',
      );
    }
    final groups = <String, List<SearchResultItem>>{};
    for (final r in _results) {
      groups.putIfAbsent(_groupLabel(r), () => []).add(r);
    }
    final names = groups.keys.toList();
    final shown = _module == null
        ? groups.entries
        : groups.entries.where((e) => e.key == _module);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        ChipRow(
          labels: [
            'All ${_results.length}',
            for (final n in names) '$n ${groups[n]!.length}',
          ],
          icons: [
            Icons.apps_rounded,
            for (final n in names) _groupIcon(n),
          ],
          selected: _module == null ? 0 : names.indexOf(_module!) + 1,
          onSelected: (i) =>
              setState(() => _module = i == 0 ? null : names[i - 1]),
        ),
        for (final entry in shown) ...[
          const SizedBox(height: 24),
          SectionHeader(
            title: entry.key,
            actionLabel: '${entry.value.length}',
          ),
          PagePad(GlassList(
            children: [
              for (final item in entry.value)
                _ResultRow(
                  item: item,
                  query: _resultQuery,
                  icon: _groupIcon(entry.key),
                  color: _groupColor(context, entry.key),
                  onTap: () => widget.onOpenRoute(item.route),
                ),
            ],
          )),
        ],
      ],
    );
  }

  static String _groupLabel(SearchResultItem item) {
    // Resolve through the real route contract so grouping matches the app's
    // navigation destinations; fall back to the backend module name.
    final dest = AppRoutes.resolveSearchRoute(item.route);
    final tab = dest.tab;
    if (tab != null) {
      return switch (tab) {
        AppTab.planner => 'Planner',
        AppTab.medicines => 'Medicines',
        AppTab.health => 'Health',
        AppTab.diet => 'Diet',
        AppTab.habits => 'Habits',
        AppTab.finance => 'Finance',
        AppTab.dashboard => 'Home',
      };
    }
    if (dest.documentId != null) return 'Documents';
    return item.module.isEmpty ? 'Results' : item.module;
  }

  static IconData _groupIcon(String group) => switch (group) {
        'Planner' => Icons.calendar_today_outlined,
        'Medicines' => Icons.medication_outlined,
        'Health' => Icons.favorite_outline,
        'Diet' => Icons.restaurant_outlined,
        'Habits' => Icons.check_circle_outline,
        'Finance' => Icons.account_balance_wallet_outlined,
        'Documents' => Icons.folder_outlined,
        _ => Icons.search,
      };

  /// Module tint for the row icon well; neutral for unknown groups.
  static Color? _groupColor(BuildContext context, String group) {
    final colors = BlistraColors.resolve(context);
    final hue = switch (group) {
      'Planner' => 40.0,
      'Medicines' => 215.0,
      'Health' => 320.0,
      'Diet' => 22.0,
      'Habits' => 262.0,
      'Finance' => 146.0,
      'Documents' => 0.0,
      _ => null,
    };
    if (hue == null) return null;
    return HSLColor.fromAHSL(
      1,
      hue,
      colors.isDark ? 0.8 : 0.7,
      colors.isDark ? 0.7 : 0.4,
    ).toColor();
  }
}

/// One result: module icon well, title with the match in the accent,
/// subtitle and a chevron.
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.item,
    required this.query,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final SearchResultItem item;
  final String query;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final base = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      color: colors.text,
    );
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
        child: Row(
          children: [
            IconWell(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: _highlight(
                        item.title,
                        query,
                        TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.accentText,
                        ),
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: base,
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.muted),
          ],
        ),
      ),
    );
  }

  /// Splits [text] into spans with every query word styled by [hit].
  static List<TextSpan> _highlight(String text, String query, TextStyle hit) {
    final words = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    if (words.isEmpty) return [TextSpan(text: text)];
    final pattern = RegExp(words.map(RegExp.escape).join('|'),
        caseSensitive: false);
    final spans = <TextSpan>[];
    var start = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > start) spans.add(TextSpan(text: text.substring(start, m.start)));
      spans.add(TextSpan(text: m.group(0), style: hit));
      start = m.end;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return spans;
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(kPageGutter, 24, kPageGutter, 32),
      children: [
        GlassCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              IconWell(icon, color: colors.accentText, size: 56),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: BlistraText.serif(20, colors.text),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.muted),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 16),
                PrimaryButton(
                  label: actionLabel!,
                  icon: Icons.refresh_rounded,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
