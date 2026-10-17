/// The month's expenses grouped by day, with search and category filters.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key, required this.onOpen});

  final ValueChanged<Expense> onOpen;

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  String _query = '';
  ExpenseCategory? _category;
  bool _sharedOnly = false;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final controller = context.watch<FinanceController>();
    final meId = controller.me?.id;
    final q = _query.trim().toLowerCase();
    final filtered = controller.expenses.where((e) {
      if (_category != null && e.category != _category) return false;
      if (_sharedOnly && !e.isShared) return false;
      if (q.isEmpty) return true;
      return e.description.toLowerCase().contains(q) ||
          (e.notes ?? '').toLowerCase().contains(q) ||
          e.category.label.toLowerCase().contains(q) ||
          e.shares.any((s) => s.user.displayName.toLowerCase().contains(q));
    }).toList();
    final used = controller.expenses.map((e) => e.category).toSet();

    final groups = <DateTime, List<Expense>>{};
    for (final e in filtered) {
      groups.putIfAbsent(DateTime(e.spentOn.year, e.spentOn.month, e.spentOn.day), () => []).add(e);
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 400 && controller.hasMoreExpenses) controller.loadMoreExpenses();
        return false;
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search this month',
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Shared'),
                  avatar: const Icon(Icons.people_alt_rounded, size: 16),
                  selected: _sharedOnly,
                  onSelected: (v) => setState(() => _sharedOnly = v),
                ),
                for (final c in ExpenseCategory.values.where(used.contains)) ...[
                  const SizedBox(width: 6),
                  FilterChip(
                    label: Text(c.label),
                    avatar: Icon(c.icon, size: 16, color: c.color),
                    selected: _category == c,
                    onSelected: (v) => setState(() => _category = v ? c : null),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Text(
                controller.expenses.isEmpty ? 'No expenses this month.' : 'Nothing matches your filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.muted),
              ),
            ),
          for (final entry in groups.entries) ...[
            SectionLabel(
              dayLabel(entry.key),
              trailing: Text(
                _dayTotal(entry.value, meId),
                style: TextStyle(fontSize: 12, color: colors.muted, fontWeight: FontWeight.w600),
              ),
            ),
            GlassCard(
              padding: const EdgeInsets.all(6),
              child: Column(
                children: [
                  for (final e in entry.value)
                    ExpenseTile(expense: e, meId: meId, onTap: () => widget.onOpen(e)),
                ],
              ),
            ),
          ],
          if (controller.loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  /// Your own share for the day, per currency.
  String _dayTotal(List<Expense> items, String? meId) {
    final totals = <String, List<Expense>>{};
    for (final e in items) {
      totals.putIfAbsent(e.currency, () => []).add(e);
    }
    return totals.entries
        .map((t) => sumMoney(t.value.map((e) => e.myShare)).display(currencyCode: t.key))
        .join(' + ');
  }
}
