/// The month's expenses grouped by day, with search and category filters.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
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
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
        children: [
          PagePad(
            GlassCard(
              radius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: TextField(
                style: TextStyle(fontSize: 14, color: colors.text),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, size: 19, color: colors.muted),
                  prefixIconConstraints: const BoxConstraints(minWidth: 30),
                  hintText: 'Search this month',
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
          ),
          const SizedBox(height: 10),
          _FilterChips(
            chips: [
              (
                label: 'Shared',
                icon: Icons.people_alt_rounded,
                on: _sharedOnly,
                onTap: () => setState(() => _sharedOnly = !_sharedOnly),
              ),
              for (final c in ExpenseCategory.values.where(used.contains))
                (
                  label: c.label,
                  icon: c.icon,
                  on: _category == c,
                  onTap: () => setState(() => _category = _category == c ? null : c),
                ),
            ],
          ),
          if (filtered.isEmpty)
            PagePad(
              EmptyCard(
                message: controller.expenses.isEmpty ? 'No expenses this month.' : 'Nothing matches your filters.',
              ),
              top: 16,
            ),
          for (final entry in groups.entries) ...[
            const SizedBox(height: 20),
            _DayHeader(label: dayLabel(entry.key), total: _dayTotal(entry.value, meId)),
            PagePad(
              GlassList(
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

/// Serif day heading with your share for the day on the right.
class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.total});

  final String label;
  final String total;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return PagePad(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(label, style: BlistraText.serif(17, colors.text)),
              ),
            ),
            Text(
              total,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: BlistraText.tabular,
                color: colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _Chip = ({String label, IconData icon, bool on, VoidCallback onTap});

/// Toggle chips styled like [ChipRow], but each one toggles on its own so
/// "Shared" combines with a category.
class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.chips});

  final List<_Chip> chips;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kPageGutter),
        clipBehavior: Clip.none,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final chip = chips[i];
          final tone = chip.on ? colors.accentText : colors.muted;
          return Semantics(
            button: true,
            selected: chip.on,
            label: chip.label,
            child: GestureDetector(
              onTap: chip.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: chip.on ? colors.accentSoft : colors.glassFill,
                  border: Border.all(
                    color: chip.on ? colors.accentText.withValues(alpha: 0.45) : colors.glassBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chip.icon, size: 15, color: tone),
                    const SizedBox(width: 6),
                    Text(
                      chip.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: tone),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
