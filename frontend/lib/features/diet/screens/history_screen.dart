import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/meal_tile.dart';
import 'meal_detail_screen.dart';

/// Paginated history of all meals with pull-to-refresh and infinite scroll.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DietController>().loadHistory(refresh: true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<DietController>().loadMoreHistory();
    }
  }

  Future<void> _refresh() async {
    await context.read<DietController>().loadHistory(refresh: true);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(day.year, day.month, day.day);
    if (that == today) {
      return 'Today';
    }
    if (that == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('EEE d MMM yyyy').format(day);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DietController>();
    final history = controller.history;

    return Scaffold(
      appBar: AppBar(title: const Text('Meal History')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            if (controller.historyLoading && history == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.historyError != null && history == null)
              ErrorState(
                message: controller.historyError!,
                onRetry: _refresh,
              )
            else if (history == null || history.content.isEmpty)
              const EmptyState(
                icon: Icons.history_outlined,
                title: 'No meals yet',
                subtitle: 'Your meal history will appear here.',
              )
            else ...[
              for (int i = 0; i < history.content.length; i++) ...[
                if (i == 0 ||
                    !_sameDay(history.content[i - 1].consumedAt,
                        history.content[i].consumedAt))
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(
                      _dayLabel(history.content[i].consumedAt),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                MealTile(
                  label: history.content[i].mealType.label,
                  title: history.content[i].title,
                  consumedAt: history.content[i].consumedAt,
                  itemCount: history.content[i].itemCount,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MealDetailScreen(
                          mealId: history.content[i].id,
                          // We could fetch the full meal, but MealDetailScreen
                          // will load it when initial is null.
                        ),
                      ),
                    );
                  },
                ),
              ],
              if (history.hasMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ],
        ),
      ),
    );
  }
}