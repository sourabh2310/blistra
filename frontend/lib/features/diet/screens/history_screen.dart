import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../models/meal.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/meal_tile.dart';
import 'meal_detail_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';

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

  void _open(MealSummary meal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        // MealDetailScreen loads the full meal when initial is null.
        builder: (_) => MealDetailScreen(mealId: meal.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final controller = context.watch<DietController>();
    final history = controller.history;
    final total = history?.totalElements ?? 0;

    // Consecutive meals grouped by local day.
    final groups = <List<MealSummary>>[];
    for (final meal in history?.content ?? const <MealSummary>[]) {
      if (groups.isEmpty ||
          !_sameDay(groups.last.first.consumedAt, meal.consumedAt)) {
        groups.add([meal]);
      } else {
        groups.last.add(meal);
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 6, bottom: 40),
            children: [
              BlistraPageHeader(
                eyebrow: 'Diet',
                title: 'Meal history',
                subtitle: history == null
                    ? null
                    : '$total ${total == 1 ? 'meal' : 'meals'} logged',
              ),
              if (controller.historyLoading && history == null)
                const PagePad(SkeletonLoader(rows: 4), top: 14)
              else if (controller.historyError != null && history == null)
                PagePad(
                  ErrorState(
                    message: controller.historyError!,
                    onRetry: _refresh,
                  ),
                  top: 14,
                )
              else if (history == null || history.content.isEmpty)
                const PagePad(
                  EmptyState(
                    icon: Icons.history_outlined,
                    title: 'No meals yet',
                    subtitle: 'Your meal history will appear here.',
                  ),
                  top: 14,
                )
              else ...[
                for (final group in groups) ...[
                  const SizedBox(height: 22),
                  SectionHeader(
                    title: _dayLabel(group.first.consumedAt),
                    actionLabel:
                        '${group.length} ${group.length == 1 ? 'meal' : 'meals'}',
                  ),
                  PagePad(
                    GlassList(
                      children: [
                        for (final meal in group)
                          MealTile(
                            label: meal.mealType.label,
                            title: meal.title,
                            mealType: meal.mealType,
                            consumedAt: meal.consumedAt,
                            itemCount: meal.itemCount,
                            onTap: () => _open(meal),
                          ),
                      ],
                    ),
                  ),
                ],
                if (history.hasMore)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(color: colors.accentText),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
