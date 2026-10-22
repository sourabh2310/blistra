import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../models/item_draft.dart';
import '../models/meal.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/diet_ui.dart';
import '../widgets/item_editor_sheet.dart';
import 'add_edit_meal_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';

/// Shows a meal with its items; allows editing the meal or its items.
class MealDetailScreen extends StatefulWidget {
  const MealDetailScreen({super.key, required this.mealId, this.initial});

  final String mealId;
  final Meal? initial;

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  Meal? _meal;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      _meal = widget.initial;
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final controller = context.read<DietController>();
    try {
      _meal = await controller.fetchMeal(widget.mealId);
    } on Exception {
      _error = 'Could not load the meal.';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refresh() async {
    await _load();
  }

  Widget _shell({
    required String title,
    String? eyebrow,
    String? subtitle,
    List<Widget> actions = const [],
    required List<Widget> children,
    Widget? bottom,
  }) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 6, bottom: 24),
            children: [
              BlistraPageHeader(
                eyebrow: eyebrow ?? 'Meal',
                title: title,
                subtitle: subtitle,
                actions: actions,
                showAvatar: false,
              ),
              ...children,
            ],
          ),
        ),
      ),
      bottomNavigationBar: bottom,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return _shell(
        title: 'Meal',
        children: const [PagePad(SkeletonLoader(rows: 3), top: 14)],
      );
    }
    if (_error != null) {
      return _shell(
        title: 'Meal',
        children: [
          PagePad(ErrorState(message: _error!, onRetry: _refresh), top: 14),
        ],
      );
    }
    if (_meal == null) {
      return _shell(
        title: 'Meal',
        children: const [
          PagePad(ErrorState(message: 'Meal not found.'), top: 14),
        ],
      );
    }

    final meal = _meal!;
    final count = meal.items.length;
    final stats = _stats(meal);
    return _shell(
      eyebrow: '${meal.mealType.label} · ${DateFormat('EEE d MMM').format(meal.consumedAt)}',
      title: meal.title,
      subtitle: '${DateFormat('h:mm a').format(meal.consumedAt)}'
          ' · $count ${count == 1 ? 'item' : 'items'}',
      actions: [
        GlassIconButton(
          tooltip: 'Edit meal',
          icon: Icons.edit_outlined,
          onTap: _editMeal,
        ),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (value) {
            if (value == 'delete') {
              _confirmDeleteMeal();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'delete', child: Text('Delete meal')),
          ],
          child: const GlassIconButton(
            tooltip: null,
            icon: Icons.more_horiz_rounded,
            onTap: null,
          ),
        ),
      ],
      bottom: StickyActionBar(label: 'Add item', onPressed: _addItem),
      children: [
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 14),
          StatStrip(stats: stats),
        ],
        if (meal.notes != null && meal.notes!.isNotEmpty)
          PagePad(
            FieldCard(label: 'Notes', child: Text(meal.notes!)),
            top: 12,
          ),
        const SizedBox(height: 24),
        SectionHeader(
          title: 'Items',
          actionLabel: 'Add ›',
          onAction: _addItem,
        ),
        PagePad(
          meal.items.isEmpty
              ? EmptyState(
                  icon: Icons.no_meals_outlined,
                  title: 'No items in this meal',
                  subtitle: 'Add items to record what you ate.',
                  action: 'Add first item',
                  onAction: _addItem,
                )
              : GlassList(
                  children: [
                    for (final item in meal.items)
                      _ItemTile(
                        item: item,
                        onEdit: () => _editItem(item),
                        onDelete: () => _deleteItem(item),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  /// Totals of the values recorded on this meal's items; a component with
  /// no recorded value on any item is left out rather than shown as zero.
  static List<StatData> _stats(Meal meal) {
    double? sum(double? Function(MealItem) pick) {
      double? total;
      for (final item in meal.items) {
        final v = pick(item);
        if (v != null) total = (total ?? 0) + v;
      }
      return total;
    }

    final kcal = sum((i) => i.caloriesKcal);
    final macros = [
      ('Protein', sum((i) => i.proteinG)),
      ('Carbs', sum((i) => i.carbohydratesG)),
      ('Fat', sum((i) => i.fatG)),
      ('Fiber', sum((i) => i.fiberG)),
    ];
    return [
      if (kcal != null)
        StatData(
          label: 'Calories',
          value: formatKcal(kcal),
          unit: 'kcal',
          sub: 'From recorded items',
          icon: Icons.local_fire_department_outlined,
        ),
      for (final (label, value) in macros)
        if (value != null)
          StatData(
            label: label,
            value: formatDietNumber(value),
            unit: 'g',
            sub: 'This meal',
          ),
    ];
  }

  void _editMeal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditMealScreen(mealId: widget.mealId, initial: _meal!),
      ),
    ).then((_) => _refresh());
  }

  Future<void> _addItem() async {
    final controller = context.read<DietController>();
    final draft = await showModalBottomSheet<ItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ItemEditorSheet(),
    );
    if (draft == null) {
      return;
    }
    final ok = await controller.addMealItem(widget.mealId, draft.toMealItem());
    if (ok && mounted) {
      _refresh();
    } else if (mounted) {
      _showError(controller.lastActionError);
    }
  }

  Future<void> _editItem(MealItem item) async {
    final controller = context.read<DietController>();
    final draft = await showModalBottomSheet<ItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemEditorSheet(initial: ItemDraft.fromMealItem(item)),
    );
    if (draft == null) {
      return;
    }
    final ok = await controller.updateMealItem(
      widget.mealId,
      item.id!,
      draft.toMealItem(),
    );
    if (ok && mounted) {
      _refresh();
    } else if (mounted) {
      _showError(controller.lastActionError);
    }
  }

  Future<void> _deleteItem(MealItem item) async {
    final controller = context.read<DietController>();
    final confirm = await confirmAction(
      context,
      title: 'Delete item?',
      message: 'Remove "${item.name}" from this meal?',
    );
    if (confirm != true) {
      return;
    }
    final ok = await controller.deleteMealItem(widget.mealId, item.id!);
    if (ok && mounted) {
      _refresh();
    } else if (mounted) {
      _showError(controller.lastActionError);
    }
  }

  Future<void> _confirmDeleteMeal() async {
    final controller = context.read<DietController>();
    final confirm = await confirmAction(
      context,
      title: 'Delete meal?',
      message: 'Delete "${_meal!.title}" and all its items? This cannot be undone.',
    );
    if (confirm != true) {
      return;
    }
    final ok = await controller.deleteMeal(widget.mealId);
    if (ok && mounted) {
      Navigator.of(context).pop(true); // signal parent to refresh
    } else if (mounted) {
      _showError(controller.lastActionError);
    }
  }

  void _showError(String? error) {
    if (error == null || error.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.onEdit, required this.onDelete});

  final MealItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassRow(
      leading: const IconWell(Icons.restaurant_rounded),
      title: item.name,
      subtitle: _buildDetailText(),
      onTap: onEdit,
      trailing: PopupMenuButton<String>(
        tooltip: 'Item actions',
        icon: Icon(Icons.more_vert_rounded, size: 19, color: colors.muted),
        onSelected: (value) {
          if (value == 'edit') {
            onEdit();
          } else if (value == 'delete') {
            onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  String _buildDetailText() {
    final parts = <String>[];
    if (item.quantity != null) {
      parts.add(_fmt(item.quantity!));
      if (item.unit != null && item.unit!.isNotEmpty) {
        parts.add(item.unit!);
      }
    }
    if (item.caloriesKcal != null) {
      parts.add('${_fmt(item.caloriesKcal!)} kcal');
    }
    if (item.proteinG != null) {
      parts.add('P: ${_fmt(item.proteinG!)}g');
    }
    if (item.carbohydratesG != null) {
      parts.add('C: ${_fmt(item.carbohydratesG!)}g');
    }
    if (item.fatG != null) {
      parts.add('F: ${_fmt(item.fatG!)}g');
    }
    if (item.fiberG != null) {
      parts.add('Fib: ${_fmt(item.fiberG!)}g');
    }
    if (parts.isEmpty) {
      return 'No nutrition recorded';
    }
    return parts.join('  ·  ');
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}