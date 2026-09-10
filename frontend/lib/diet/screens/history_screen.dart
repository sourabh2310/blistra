import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../models/meal.dart';
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
              for (final meal in history.content)
                MealTile(
                  label: meal.mealType.label,
                  title: meal.title,
                  consumedAt: meal.consumedAt,
                  itemCount: meal.itemCount,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MealDetailScreen(
                          mealId: meal.id,
                          // We could fetch the full meal, but MealDetailScreen
                          // will load it when initial is null.
                        ),
                      ),
                    );
                  },
                ),
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