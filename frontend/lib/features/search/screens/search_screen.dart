/// Global search over the user's own data (backend `/api/v1/search`).
///
/// Results group by domain and open the owning detail screen via
/// [AppRoutes.resolveSearchRoute]. Empty/error states are explicit; nothing
/// is ever fabricated.
library;

import 'package:flutter/material.dart';

import '../../../core/routing/routes.dart';
import '../search_api.dart';

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
        _searched = true;
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      appBar: AppBar(
        title: const Text('Search'),
        backgroundColor: const Color(0xFFFFFBF6),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Semantics(
              label: 'Search your data',
              textField: true,
              child: TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'What are you looking for?',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            _controller.clear();
                            _run('');
                          },
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: _run,
              ),
            ),
          ),
          if (_searching) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body()),
        ],
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(entry.key,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF667085))),
          ),
          for (final item in entry.value)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(_groupIcon(entry.key),
                    color: const Color(0xFF0C6B6B)),
                title: Text(item.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: item.subtitle.isEmpty
                    ? null
                    : Text(item.subtitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => widget.onOpenRoute(item.route),
              ),
            ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE6F6F3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 36, color: const Color(0xFF0C6B6B)),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF667085),
                    ),
                textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
