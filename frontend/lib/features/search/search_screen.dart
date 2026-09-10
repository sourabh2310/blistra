import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/search_api.dart';
import '../models/search_result.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final SearchApi _searchApi = SearchApi();

  List<SearchResult> _results = [];
  bool _isLoading = false;
  String? _error;
  int _page = 0;
  bool _hasMore = true;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query, {bool loadMore = false}) async {
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _hasMore = false;
        _error = null;
      });
      return;
    }

    if (_isLoading) return;

    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 0;
        _lastQuery = query.trim();
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await _searchApi.search(
        query: _lastQuery,
        page: _page,
        size: 20,
      );

      if (!mounted) return;

      if (loadMore) {
        _results.addAll(response.results);
      } else {
        _results = response.results;
      }

      setState(() {
        _isLoading = false;
        _hasMore = response.results.length >= 20 && response.page < response.totalPages - 1;
        _page++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Search failed: ${e.toString()}';
      });
    }
  }

  void _onQueryChanged(String value) {
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _hasMore = false;
        _error = null;
      });
      return;
    }

    _performSearch(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: 'Search tasks, medicines, meals, health...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          setState(() {
                            _results = [];
                            _hasMore = false;
                            _error = null;
                          });
                          _focusNode.requestFocus();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: _performSearch,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_isLoading && _results.isEmpty)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_results.isEmpty && _controller.text.trim().length >= 2 && !_isLoading)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No results found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (scrollInfo) {
                  if (!_isLoading &&
                      _hasMore &&
                      scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200) {
                    _performSearch(_lastQuery, loadMore: true);
                  }
                  return false;
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _results.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return _SearchResultTile(result: _results[index]);
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final SearchResult result;

  const _SearchResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moduleColor = _getModuleColor(result.module);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: moduleColor.withValues(alpha: 0.2),
          child: Icon(_getModuleIcon(result.module), color: moduleColor),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.subtitle != null && result.subtitle!.isNotEmpty)
              Text(
                result.subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: moduleColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.module,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: moduleColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    result.type,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _navigateToResult(context, result),
      ),
    );
  }

  Color _getModuleColor(String module) {
    switch (module) {
      case 'PLANNER':
        return Colors.blue;
      case 'MEDICINES':
        return Colors.green;
      case 'HEALTH':
        return Colors.red;
      case 'DIET':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getModuleIcon(String module) {
    switch (module) {
      case 'PLANNER':
        return Icons.event_note;
      case 'MEDICINES':
        return Icons.medication;
      case 'HEALTH':
        return Icons.favorite;
      case 'DIET':
        return Icons.restaurant;
      default:
        return Icons.search;
    }
  }

  void _navigateToResult(BuildContext context, SearchResult result) {
    // Navigate based on type and route
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigate to ${result.route} (${result.type})'),
        duration: const Duration(seconds: 2),
      ),
    );
    // TODO: Implement actual navigation when routes are available
  }
}