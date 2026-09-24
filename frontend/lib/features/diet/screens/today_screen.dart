import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/auth_state.dart';
import '../diet_controller.dart';
import '../models/water.dart';
import '../validators.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/meal_tile.dart';
import '../widgets/nutrition_card.dart';
import '../widgets/trends_card.dart';
import 'add_edit_meal_screen.dart';
import 'history_screen.dart';
import 'meal_detail_screen.dart';
import 'profile_screen.dart';

/// The default Diet view: the selected local calendar day with its water,
/// nutrition and meal list, plus quick water entry.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  final _waterAmount = TextEditingController();
  WaterUnit _waterUnit = WaterUnit.ml;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<DietController>();
      if (controller.summary == null) {
        controller.loadSummary();
      }
    });
  }

  @override
  void dispose() {
    _waterAmount.dispose();
    super.dispose();
  }

  Future<void> _addWater() async {
    final amount = Validators.waterAmount(_waterAmount.text);
    if (amount != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(amount)));
      return;
    }
    final ok = await _recordWater(
      double.parse(_waterAmount.text.trim()),
      _waterUnit.wireName,
    );
    if (ok) {
      setState(() => _waterAmount.clear());
    }
  }

  Future<void> _quickAddWater(double milliliters) async {
    await _recordWater(milliliters, WaterUnit.ml.wireName);
  }

  Future<bool> _recordWater(double amount, String unit) async {
    final controller = context.read<DietController>();
    final ok = await controller.addWater(amount: amount, unit: unit);
    if (!mounted) {
      return ok;
    }
    if (!ok) {
      final error = controller.lastActionError;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DietController>();
    final summary = controller.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Diet profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                context.read<AuthState>().logout();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Sign out')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.loadSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          children: [
            _DayHeader(
              date: controller.selectedDate,
              onPrev: () => controller.shiftDate(-1),
              onNext: () => controller.shiftDate(1),
              onToday: () => controller.selectDate(DateTime.now()),
            ),
            const SizedBox(height: 12),
            _WaterCard(
              controller: _waterAmount,
              unit: _waterUnit,
              onUnitChanged: (unit) => setState(() => _waterUnit = unit),
              onAdd: _addWater,
              onQuickAdd: _quickAddWater,
              waterCount: summary?.waterCount ?? 0,
              waterTotal: summary?.waterTotalMilliliters,
            ),
            const SizedBox(height: 12),
            if (controller.summaryLoading && summary == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (controller.summaryError != null && summary == null)
              ErrorState(
                message: controller.summaryError!,
                onRetry: controller.loadSummary,
              )
            else if (summary == null)
              const ErrorState(message: 'Nothing to show yet.')
            else ...[
              NutritionSummaryCard(nutrition: summary.nutrition),
              const SizedBox(height: 12),
              if (summary.meals.isEmpty)
                const EmptyState(
                  icon: Icons.no_meals_outlined,
                  title: 'No meals recorded',
                  subtitle: 'Tap + to log today\'s first meal.',
                )
              else
                Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                        child: Row(
                          children: [
                            Text('Meals', style: Theme.of(context).textTheme.titleSmall),
                            const Spacer(),
                            Text(
                              '${summary.mealCount} ${summary.mealCount == 1 ? 'meal' : 'meals'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      for (final meal in summary.meals)
                        MealTile(
                          label: meal.mealType.label,
                          title: meal.title,
                          consumedAt: meal.consumedAt,
                          itemCount: meal.items.length,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MealDetailScreen(mealId: meal.id, initial: meal),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const TrendsCard(),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AddEditMealScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Add meal'),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.date,
    required this.onPrev,
    required this.onNext,
    required this.onToday,
  });

  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onToday;

  bool get _isToday {
    final now = DateTime.now();
    return now.year == date.year && now.month == date.month && now.day == date.day;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: InkWell(
            onTap: onToday,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              children: [
                Text(
                  DateFormat('EEEE, MMM d').format(date),
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                if (!_isToday)
                  Text(
                    'Tap to jump to today',
                    style: textTheme.bodySmall?.copyWith(color: scheme.outline),
                  ),
              ],
            ),
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
    required this.onAdd,
    required this.onQuickAdd,
    required this.waterCount,
    required this.waterTotal,
  });

  final TextEditingController controller;
  final WaterUnit unit;
  final ValueChanged<WaterUnit> onUnitChanged;
  final VoidCallback onAdd;
  final ValueChanged<double> onQuickAdd;
  final int waterCount;
  final double? waterTotal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    String totalText = '—';
    if (waterTotal != null) {
      totalText = waterTotal! >= 1000
          ? '${(waterTotal! / 1000).toStringAsFixed(1)} L'
          : '${waterTotal!.round()} ml';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                Text('Water', style: textTheme.titleSmall),
                const Spacer(),
                Text(
                  '$waterCount ${waterCount == 1 ? 'entry' : 'entries'}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              totalText,
              style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onAdd(),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'e.g. 250',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<WaterUnit>(
                  value: unit,
                  items: [
                    for (final u in WaterUnit.values)
                      DropdownMenuItem(value: u, child: Text(u.label)),
                  ],
                  onChanged: (u) {
                    if (u != null) {
                      onUnitChanged(u);
                    }
                  },
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Add water',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('+250 ml'),
                  onPressed: () => onQuickAdd(250),
                ),
                ActionChip(
                  label: const Text('+500 ml'),
                  onPressed: () => onQuickAdd(500),
                ),
              ],
            ),
            if (waterCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Glasses and cups are listed but not part of the millilitre total.',
                  style: textTheme.bodySmall?.copyWith(color: scheme.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}