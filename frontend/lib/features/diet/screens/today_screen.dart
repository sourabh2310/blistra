import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../notifications/screens/reminders_screen.dart';
import '../diet_controller.dart';
import '../models/meal.dart';
import '../models/summary.dart';
import '../models/water.dart';
import '../validators.dart';
import '../widgets/diet_dashboard_widgets.dart';
import 'add_edit_meal_screen.dart';
import 'history_screen.dart';
import 'meal_detail_screen.dart';
import 'profile_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<DietController>();
      if (controller.summary == null) {
        controller.loadSummary();
      }
    });
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    if (mounted) {
      await context.read<DietController>().loadSummary(refresh: true);
    }
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  Future<void> _openMeal(Meal meal) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MealDetailScreen(mealId: meal.id, initial: meal),
      ),
    );
    if (mounted) {
      await context.read<DietController>().loadSummary();
    }
  }

  Future<void> _createMeal() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddEditMealScreen()),
    );
  }

  void _selectTab(int index) {
    setState(() => _selectedTab = index);
    if (index == 4) {
      final controller = context.read<DietController>();
      if (controller.profile == null) {
        controller.loadProfile();
      }
    }
  }

  void _showNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Reminders')),
          body: RemindersScreen(onRefresh: () async {}),
        ),
      ),
    );
  }

  void _showSearch(DietSummary summary) {
    showDialog<void>(
      context: context,
      builder: (context) => _FoodSearchDialog(
        summary: summary,
        onMealSelected: (meal) {
          Navigator.of(context).pop();
          _openMeal(meal);
        },
      ),
    );
  }

  void _showScanMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Food scanning is unavailable because this app has no scanner. You can still log a meal manually.',
        ),
      ),
    );
  }

  Future<void> _showWaterLog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _WaterLogSheet(onRecord: _recordWater),
    );
  }

  Future<bool> _recordWater(double amount, WaterUnit unit) async {
    final controller = context.read<DietController>();
    final now = DateTime.now();
    final selected = controller.selectedDate;
    final consumedAt = DateTime(
      selected.year,
      selected.month,
      selected.day,
      now.hour,
      now.minute,
      now.second,
    );
    final ok = await controller.addWater(
      amount: amount,
      unit: unit.wireName,
      consumedAt: consumedAt,
    );
    if (!mounted) return ok;
    if (!ok) {
      final error = controller.lastActionError;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DietController>();
    final summary = controller.summary;
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBF6),
      floatingActionButton: FloatingActionButton(
        heroTag: 'diet-add-meal',
        elevation: 6,
        backgroundColor: const Color(0xFF064F4A),
        foregroundColor: Colors.white,
        tooltip: 'Log a meal',
        onPressed: _createMeal,
        child: const Icon(Icons.add_rounded, size: 32),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.loadSummary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              DietBrandHeader(
                onSearch: () {
                  if (summary != null) {
                    _showSearch(summary);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Food search is available after the day loads.')),
                    );
                  }
                },
                onNotifications: _showNotifications,
                onHistory: _openHistory,
                onProfile: _openProfile,
              ),
              const SizedBox(height: 18),
              const DietHero(),
              const SizedBox(height: 14),
              _DietTabs(selected: _selectedTab, onSelected: _selectTab),
              const SizedBox(height: 16),
              if (controller.summaryLoading && summary == null)
                const _PageLoading()
              else if (controller.summaryError != null && summary == null)
                _PageError(
                  message: controller.summaryError!,
                  onRetry: controller.loadSummary,
                )
              else if (summary == null)
                const _PageError(message: 'Diet data is not available yet.')
              else
                _buildTabContent(controller, summary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(
    DietController controller,
    DietSummary summary,
  ) {
    final onQuickMeal = _createMeal;
    final quickActions = DietQuickActions(
      onLogMeal: onQuickMeal,
      onLogWater: _showWaterLog,
      onScanFood: _showScanMessage,
    );
    switch (_selectedTab) {
      case 1:
        return Column(
          children: [
            TodayMealsSection(
              summary: summary,
              date: controller.selectedDate,
              onPrevious: () => controller.shiftDate(-1),
              onNext: () => controller.shiftDate(1),
              onToday: () => controller.selectDate(DateTime.now()),
              onMealTap: _openMeal,
              onAddMeal: onQuickMeal,
            ),
            const SizedBox(height: 12),
            quickActions,
          ],
        );
      case 2:
        return Column(
          children: [
            NutritionOverviewSection(summary: summary, date: controller.selectedDate),
            const SizedBox(height: 12),
            quickActions,
          ],
        );
      case 3:
        return RecentFoodLogSection(
          summary: summary,
          onMealTap: _openMeal,
          onSeeAll: _openHistory,
          limit: null,
        );
      case 4:
        return DietGoalsSection(
          profile: controller.profile,
          loading: controller.profileLoading,
          onOpenProfile: _openProfile,
          onRetry: controller.loadProfile,
        );
      default:
        return Column(
          children: [
            DietSummaryGrid(summary: summary),
            const SizedBox(height: 12),
            TodayMealsSection(
              summary: summary,
              date: controller.selectedDate,
              onPrevious: () => controller.shiftDate(-1),
              onNext: () => controller.shiftDate(1),
              onToday: () => controller.selectDate(DateTime.now()),
              onMealTap: _openMeal,
              onAddMeal: onQuickMeal,
            ),
            const SizedBox(height: 12),
            quickActions,
            const SizedBox(height: 12),
            NutritionOverviewSection(
              summary: summary,
              date: controller.selectedDate,
            ),
            const SizedBox(height: 12),
            RecentFoodLogSection(
              summary: summary,
              onMealTap: _openMeal,
              onSeeAll: _openHistory,
            ),
          ],
        );
    }
  }
}

class _DietTabs extends StatelessWidget {
  const _DietTabs({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['Today', 'Meals', 'Nutrition', 'Food Log', 'Goals'];
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24415E).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => onSelected(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == i ? const Color(0xFFDDEAE3) : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: selected == i
                            ? const Color(0xFF075E55)
                            : const Color(0xFF172554),
                        fontSize: 12,
                        fontWeight: selected == i ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WaterLogSheet extends StatefulWidget {
  const _WaterLogSheet({required this.onRecord});

  final Future<bool> Function(double amount, WaterUnit unit) onRecord;

  @override
  State<_WaterLogSheet> createState() => _WaterLogSheetState();
}

class _WaterLogSheetState extends State<_WaterLogSheet> {
  final _amount = TextEditingController();
  WaterUnit _unit = WaterUnit.ml;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = Validators.waterAmount(_amount.text);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _saving = true);
    final ok = await widget.onRecord(double.parse(_amount.text.trim()), _unit);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Water logged')),
      );
    }
  }

  Future<void> _quickAdd(double amount, WaterUnit unit) async {
    setState(() => _saving = true);
    final ok = await widget.onRecord(amount, unit);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Water logged')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.water_drop_rounded, color: Color(0xFF168CEB), size: 30),
                SizedBox(width: 9),
                Text(
                  'Log water',
                  style: TextStyle(
                    color: Color(0xFF172554),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: 'e.g. 250',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButtonFormField<WaterUnit>(
                  initialValue: _unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                  items: [
                    for (final unit in WaterUnit.values)
                      DropdownMenuItem(value: unit, child: Text(unit.label)),
                  ],
                  onChanged: (unit) {
                    if (unit != null) setState(() => _unit = unit);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('+250 ml'),
                  onPressed: _saving ? null : () => _quickAdd(250, WaterUnit.ml),
                ),
                ActionChip(
                  label: const Text('+500 ml'),
                  onPressed: _saving ? null : () => _quickAdd(500, WaterUnit.ml),
                ),
                ActionChip(
                  label: const Text('+1 L'),
                  onPressed: _saving ? null : () => _quickAdd(1, WaterUnit.L),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Only ml and litre entries contribute to the daily millilitre total.',
              style: TextStyle(color: Color(0xFF5573A4), fontSize: 12),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.water_drop_rounded),
                label: const Text('Log water'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodSearchDialog extends StatefulWidget {
  const _FoodSearchDialog({required this.summary, required this.onMealSelected});

  final DietSummary summary;
  final ValueChanged<Meal> onMealSelected;

  @override
  State<_FoodSearchDialog> createState() => _FoodSearchDialogState();
}

class _FoodSearchDialogState extends State<_FoodSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final meals = widget.summary.meals.where((meal) {
      if (query.isEmpty) return true;
      if (meal.title.toLowerCase().contains(query)) return true;
      return meal.items.any((item) => item.name.toLowerCase().contains(query));
    }).toList();
    return AlertDialog(
      title: const Text('Search this day'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Meal or food name',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: meals.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No matching meals on this day.'),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: meals.length,
                      itemBuilder: (context, index) {
                        final meal = meals[index];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(meal.mealType.label.substring(0, 1)),
                          ),
                          title: Text(meal.title),
                          subtitle: Text(
                            meal.items.map((item) => item.name).join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => widget.onMealSelected(meal),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _PageLoading extends StatelessWidget {
  const _PageLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 280,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_outlined, size: 38),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try again'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
