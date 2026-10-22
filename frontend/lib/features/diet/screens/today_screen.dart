import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../notifications/screens/reminders_screen.dart';
import '../diet_controller.dart';
import '../models/meal.dart';
import '../models/meal_type.dart';
import '../models/summary.dart';
import '../models/water.dart';
import '../validators.dart';
import '../widgets/diet_dashboard_widgets.dart';
import '../widgets/diet_ui.dart';
import '../widgets/trends_card.dart';
import 'add_edit_meal_screen.dart';
import 'history_screen.dart';
import 'meal_detail_screen.dart';
import 'profile_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _waterBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<DietController>();
      if (controller.summary == null) {
        controller.loadSummary();
      }
      if (controller.profile == null && !controller.profileLoading) {
        controller.loadProfile();
      }
    });
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HistoryScreen()),
    );
    if (mounted) {
      await context.read<DietController>().loadSummary();
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

  Future<void> _createMeal([MealType? type]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddEditMealScreen(initialType: type)),
    );
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

  Future<void> _quickWater(double ml) async {
    setState(() => _waterBusy = true);
    final ok = await _recordWater(ml, WaterUnit.ml);
    if (!mounted) return;
    setState(() => _waterBusy = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${ml.round()} ml water logged')),
      );
    }
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

  void _onMenu(String value, DietSummary? summary) {
    switch (value) {
      case 'search':
        if (summary != null) {
          _showSearch(summary);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Food search is available after the day loads.')),
          );
        }
      case 'water':
        _showWaterLog();
      case 'profile':
        _openProfile();
      case 'reminders':
        _showNotifications();
      case 'scan':
        _showScanMessage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final controller = context.watch<DietController>();
    final summary = controller.summary;
    final date = controller.selectedDate;
    final today = _isToday(date);
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'diet-add-meal',
        elevation: 6,
        backgroundColor: colors.accentText,
        foregroundColor: colors.onAccent,
        tooltip: 'Log a meal',
        onPressed: _createMeal,
        child: const Icon(Icons.add_rounded, size: 30),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: controller.loadSummary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 6, bottom: 120),
            children: [
              BlistraPageHeader(
                eyebrow: today
                    ? 'Diet · Today'
                    : 'Diet · ${DateFormat('EEE d MMM').format(date)}',
                title: _title(summary),
                subtitle: _subtitle(controller, summary),
                actions: [
                  GlassIconButton(
                    tooltip: 'Meal history',
                    icon: Icons.history_rounded,
                    onTap: _openHistory,
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (value) => _onMenu(value, summary),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'search', child: Text('Search this day')),
                      PopupMenuItem(value: 'water', child: Text('Log water…')),
                      PopupMenuItem(value: 'profile', child: Text('Diet profile')),
                      PopupMenuItem(value: 'reminders', child: Text('Reminders')),
                      PopupMenuItem(value: 'scan', child: Text('Scan food')),
                    ],
                    child: const GlassIconButton(
                      tooltip: null,
                      icon: Icons.more_horiz_rounded,
                      onTap: null,
                    ),
                  ),
                ],
              ),
              PagePad(
                _DayNav(
                  date: date,
                  onPrevious: () => controller.shiftDate(-1),
                  onNext: () => controller.shiftDate(1),
                  onToday: () => controller.selectDate(DateTime.now()),
                ),
              ),
              if (controller.summaryLoading && summary == null)
                const PagePad(SkeletonLoader(rows: 4, rowHeight: 72), top: 10)
              else if (controller.summaryError != null && summary == null)
                PagePad(
                  EmptyCard(
                    message: controller.summaryError!,
                    action: 'Retry',
                    onAction: controller.loadSummary,
                  ),
                  top: 10,
                )
              else if (summary == null)
                const PagePad(
                  EmptyCard(message: 'Diet data is not available yet.'),
                  top: 10,
                )
              else
                ..._content(controller, summary, today),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    DietController controller,
    DietSummary summary,
    bool today,
  ) {
    return [
      PagePad(DietMacrosCard(nutrition: summary.nutrition), top: 10),
      PagePad(
        DietWaterCard(
          summary: summary,
          busy: _waterBusy,
          onAdd: _quickWater,
          onCustom: _showWaterLog,
        ),
        top: 10,
      ),
      const SizedBox(height: 24),
      SectionHeader(
        title: 'Meals',
        actionLabel: 'History ›',
        onAction: _openHistory,
      ),
      PagePad(
        DietMealSlots(
          meals: summary.meals,
          onMealTap: _openMeal,
          onLog: today ? _createMeal : null,
        ),
      ),
      const SizedBox(height: 24),
      SectionHeader(
        title: 'Last 7 days',
        actionLabel: 'Trends ›',
        onAction: () => showDietTrendsSheet(context),
      ),
      PagePad(TrendsCard(token: summary)),
      const SizedBox(height: 24),
      SectionHeader(
        title: 'Diet profile',
        actionLabel: 'Edit ›',
        onAction: _openProfile,
      ),
      PagePad(
        DietProfileCard(
          profile: controller.profile,
          loading: controller.profileLoading,
          onOpen: _openProfile,
        ),
      ),
    ];
  }

  static String _title(DietSummary? summary) {
    if (summary == null) return 'Diet';
    final kcal = summary.nutrition?.caloriesKcal?.total;
    if (kcal == null) {
      return summary.meals.isEmpty ? '0 kcal' : 'No kcal recorded';
    }
    return '${formatKcal(kcal)} kcal';
  }

  static String? _subtitle(DietController controller, DietSummary? summary) {
    if (summary == null) {
      return controller.summaryLoading ? 'Getting your day ready…' : null;
    }
    final count = summary.meals.isEmpty ? summary.mealCount : summary.meals.length;
    if (count == 0) return 'No meals logged yet';
    final meals = '$count ${count == 1 ? 'meal' : 'meals'} logged';
    if (summary.meals.isEmpty) return meals;
    final last = summary.meals
        .map((m) => m.consumedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    return '$meals · last at ${DateFormat('h:mm a').format(last)}';
  }
}

bool _isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

/// Previous / next day controls under the header.
class _DayNav extends StatelessWidget {
  const _DayNav({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  final DateTime date;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final today = _isToday(date);
    Widget arrow(IconData icon, String tooltip, VoidCallback onTap) => IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          visualDensity: VisualDensity.compact,
          iconSize: 20,
          color: colors.muted,
          icon: Icon(icon),
        );
    return Row(
      children: [
        Transform.translate(
          offset: const Offset(-8, 0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              arrow(Icons.chevron_left_rounded, 'Previous day', onPrevious),
              Text(
                today ? 'Today' : DateFormat('EEE, d MMM').format(date),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              arrow(Icons.chevron_right_rounded, 'Next day', onNext),
            ],
          ),
        ),
        const Spacer(),
        if (!today) Pill('Back to today', onTap: onToday),
      ],
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

  static const _units = [
    (WaterUnit.ml, 'ml'),
    (WaterUnit.L, 'litres'),
    (WaterUnit.glass, 'glasses'),
    (WaterUnit.cup, 'cups'),
  ];

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
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        kPageGutter,
        0,
        kPageGutter,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Log water', style: BlistraText.serif(22, colors.text)),
            const SizedBox(height: 4),
            Text(
              'Only ml and litre entries contribute to the daily millilitre total.',
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            DietTextField(
              label: 'Amount',
              controller: _amount,
              hint: 'e.g. 250',
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            GlassSegmented<WaterUnit>(
              options: _units,
              selected: _unit,
              onChanged: (unit) => setState(() => _unit = unit),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Pill('+250 ml',
                    onTap: _saving ? null : () => _quickAdd(250, WaterUnit.ml)),
                Pill('+500 ml',
                    onTap: _saving ? null : () => _quickAdd(500, WaterUnit.ml)),
                Pill('+1 L',
                    onTap: _saving ? null : () => _quickAdd(1, WaterUnit.L)),
              ],
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onAccent,
                      ),
                    )
                  : const Text('Log water'),
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
    final colors = BlistraColors.resolve(context);
    final query = _query.trim().toLowerCase();
    final meals = widget.summary.meals.where((meal) {
      if (query.isEmpty) return true;
      if (meal.title.toLowerCase().contains(query)) return true;
      return meal.items.any((item) => item.name.toLowerCase().contains(query));
    }).toList();
    return AlertDialog(
      title: Text('Search this day', style: BlistraText.serif(20, colors.text)),
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
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No matching meals on this day.',
                        style: TextStyle(color: colors.muted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: meals.length,
                      itemBuilder: (context, index) {
                        final meal = meals[index];
                        return GlassRow(
                          leading: IconWell(mealTypeIcon(meal.mealType)),
                          title: meal.title,
                          subtitle: meal.items.map((item) => item.name).join(', '),
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
