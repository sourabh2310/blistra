import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../diet_controller.dart';
import '../models/item_draft.dart';
import '../models/meal.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_state.dart';
import '../widgets/item_editor_sheet.dart';
import 'add_edit_meal_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal')),
        body: ErrorState(message: _error!, onRetry: _refresh),
      );
    }
    if (_meal == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meal')),
        body: const ErrorState(message: 'Meal not found.'),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_meal!.title),
        actions: [
          IconButton(
            tooltip: 'Edit meal',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editMeal,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDeleteMeal();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete meal')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(_meal!.mealType.label.substring(0, 1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _meal!.mealType.label,
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('EEEE, MMM d, y • h:mm a').format(_meal!.consumedAt),
                        style: textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_meal!.notes != null && _meal!.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_meal!.notes!),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_meal!.items.isEmpty)
              const EmptyState(
                icon: Icons.no_meals_outlined,
                title: 'No items in this meal',
                subtitle: 'Add items to record what you ate.',
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text('Items', style: textTheme.titleSmall),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add item'),
                    ),
                  ],
                ),
              ),
              for (final item in _meal!.items) _ItemTile(item: item, onEdit: _editItem, onDelete: _deleteItem),
            ],
          ],
        ),
      ),
    );
  }

  void _editMeal() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditMealScreen(mealId: widget.mealId, initial: _meal!),
      ),
    ).then((_) => _refresh());
  }

  Future<void> _addItem() async {
    final draft = await showModalBottomSheet<ItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const ItemEditorSheet(),
    );
    if (draft == null) {
      return;
    }
    final controller = context.read<DietController>();
    final ok = await controller.addMealItem(widget.mealId, draft.toMealItem());
    if (ok && mounted) {
      _refresh();
    } else if (mounted) {
      _showError(controller.lastActionError);
    }
  }

  Future<void> _editItem(MealItem item) async {
    final draft = await showModalBottomSheet<ItemDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemEditorSheet(initial: ItemDraft.fromMealItem(item)),
    );
    if (draft == null) {
      return;
    }
    final controller = context.read<DietController>();
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.name}" from this meal?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    final controller = context.read<DietController>();
    final ok = await controller.deleteMealItem(widget.mealId, item.id!);
    if (ok && mounted) {
      _refresh();
    } else if (mounted) {
      _showError(controller.lastActionError);
    }
  }

  Future<void> _confirmDeleteMeal() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Delete "${_meal!.title}" and all its items? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    final controller = context.read<DietController>();
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
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        title: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          _buildDetailText(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
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
        onTap: onEdit,
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