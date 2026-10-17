/// Month at a glance: what you spent (your own share), versus last month
/// and your budget, where it went, day by day, and who owes whom.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.onOpenFriends,
    required this.onAddExpense,
  });

  final VoidCallback onOpenFriends;
  final VoidCallback onAddExpense;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final controller = context.watch<FinanceController>();
    final overview = controller.overview;
    final section = controller.primaryOverview;
    final currency = section?.currency ?? controller.currency;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
      children: [
        _SpentCard(
          section: section,
          currency: currency,
          isCurrentMonth: controller.isCurrentMonth,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Spending includes your trip shares. Friend balances below are separate from Groups.',
          ),
        ),
        if (overview != null &&
            (overview.owedToYou.isNotEmpty ||
                overview.youOwe.isNotEmpty ||
                overview.pendingRequests > 0))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GlassCard(
              onTap: onOpenFriends,
              child: Row(
                children: [
                  Expanded(
                    child: _BalanceColumn(
                      label: 'Owed to you',
                      amounts: overview.owedToYou,
                      color: owedColor,
                    ),
                  ),
                  Container(width: 1, height: 44, color: colors.glassBorder),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BalanceColumn(
                      label: 'You owe',
                      amounts: overview.youOwe,
                      color: oweColor,
                    ),
                  ),
                  if (overview.pendingRequests > 0)
                    Badge(
                      label: Text('${overview.pendingRequests}'),
                      child: const Icon(Icons.person_add_alt_1_rounded),
                    )
                  else
                    Icon(Icons.chevron_right_rounded, color: colors.muted),
                ],
              ),
            ),
          ),
        if (section == null || section.byCategory.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Column(
              children: [
                Icon(Icons.receipt_long_rounded, size: 44, color: colors.muted),
                const SizedBox(height: 10),
                Text(
                  'No expenses this month yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Log what you spend, or split a bill with a friend.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onAddExpense,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add expense'),
                ),
              ],
            ),
          )
        else ...[
          const SectionLabel('Daily spending'),
          GlassCard(
            child: _DailyBars(section: section, month: controller.month),
          ),
          const SectionLabel('Where it went'),
          GlassCard(
            child: Column(
              children: [
                for (final c in section.byCategory)
                  _CategoryRow(
                    item: c,
                    total: section.spent,
                    currency: currency,
                    budget: section.budgets
                        .where((b) => b.category == c.category)
                        .firstOrNull,
                  ),
              ],
            ),
          ),
        ],
        SectionLabel(
          'Budgets',
          trailing: TextButton.icon(
            onPressed: () => showBudgetSheet(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add'),
          ),
        ),
        if (section == null || section.budgets.isEmpty)
          Text(
            'Set a monthly limit to see how you\'re tracking.',
            style: TextStyle(color: colors.muted),
          )
        else
          GlassCard(
            child: Column(
              children: [
                for (final b in section.budgets) _BudgetRow(budget: b),
              ],
            ),
          ),
        if ((overview?.currencies.length ?? 0) > 1) ...[
          const SectionLabel('Other currencies'),
          for (final c in overview!.currencies.where(
            (c) => c.currency != currency,
          ))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.currency),
              trailing: Text(
                c.spent.display(currencyCode: c.currency),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: colors.text,
                ),
              ),
              onTap: () => controller.setCurrency(c.currency),
            ),
        ],
      ],
    );
  }
}

class _SpentCard extends StatelessWidget {
  const _SpentCard({
    required this.section,
    required this.currency,
    required this.isCurrentMonth,
  });

  final CurrencyOverview? section;
  final String currency;
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final spent = section?.spent ?? Money.zero();
    final previous = section?.previousMonthSpent ?? Money.zero();
    final budget = section?.overallBudget;
    String? trend;
    Color? trendColor;
    if (!previous.isZero) {
      final change =
          (spent.toDouble() - previous.toDouble()) / previous.toDouble() * 100;
      trend =
          '${change >= 0 ? '▲' : '▼'} ${change.abs().toStringAsFixed(0)}% vs last month';
      trendColor = change > 0 ? oweColor : owedColor;
    }
    return GlassCard(
      tint: colors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isCurrentMonth ? 'Spent this month' : 'Spent',
            style: TextStyle(color: colors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            spent.display(currencyCode: currency),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              color: colors.text,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (trend != null)
                Text(
                  trend,
                  style: TextStyle(
                    color: trendColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (isCurrentMonth &&
                  section != null &&
                  !section!.todaySpent.isZero)
                Text(
                  '${section!.todaySpent.display(currencyCode: currency)} today',
                  style: TextStyle(color: colors.muted),
                ),
              if (section != null && section!.paid > section!.spent)
                Text(
                  'You paid ${section!.paid.display(currencyCode: currency)} in total',
                  style: TextStyle(color: colors.muted),
                ),
            ],
          ),
          if (budget != null) ...[
            const SizedBox(height: 14),
            ProgressLine(
              value: budget.usage,
              color: budget.over ? oweColor : colors.accent,
            ),
            const SizedBox(height: 6),
            Text(
              budget.over
                  ? '${(budget.spent - budget.limit).display(currencyCode: currency)} over your ${budget.limit.display(currencyCode: currency)} budget'
                  : '${(budget.limit - budget.spent).display(currencyCode: currency)} left of ${budget.limit.display(currencyCode: currency)}',
              style: TextStyle(
                color: budget.over ? oweColor : colors.muted,
                fontSize: 12.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceColumn extends StatelessWidget {
  const _BalanceColumn({
    required this.label,
    required this.amounts,
    required this.color,
  });

  final String label;
  final List<CurrencyAmount> amounts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: colors.muted, fontSize: 12.5)),
        const SizedBox(height: 4),
        Text(
          amounts.isEmpty ? '—' : amounts.map((a) => a.display).join(' + '),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: amounts.isEmpty ? colors.muted : color,
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.total,
    required this.currency,
    this.budget,
  });

  final CategoryAmount item;
  final Money total;
  final String currency;
  final Budget? budget;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final share = total.isZero
        ? 0.0
        : item.amount.toDouble() / total.toDouble();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          CategoryAvatar(item.category, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.category.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: colors.text,
                        ),
                      ),
                    ),
                    Text(
                      item.amount.display(currencyCode: currency),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: colors.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressLine(
                  value: budget != null ? budget!.usage : share,
                  color: budget != null && budget!.over
                      ? oweColor
                      : item.category.color,
                ),
                const SizedBox(height: 3),
                Text(
                  budget != null
                      ? '${(budget!.usage * 100).toStringAsFixed(0)}% of ${budget!.limit.display(currencyCode: currency)} budget'
                      : '${(share * 100).toStringAsFixed(0)}% of spending',
                  style: TextStyle(fontSize: 11.5, color: colors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return InkWell(
      onTap: () => showBudgetSheet(context, existing: budget),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  budget.category?.icon ?? Icons.savings_rounded,
                  size: 18,
                  color: budget.category?.color ?? colors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    budget.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                  ),
                ),
                Text(
                  '${budget.spent.display(currencyCode: budget.currency)} / ${budget.limit.display(currencyCode: budget.currency)}',
                  style: TextStyle(
                    color: budget.over ? oweColor : colors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ProgressLine(
              value: budget.usage,
              color: budget.over
                  ? oweColor
                  : (budget.category?.color ?? colors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple bar per day of the month.
class _DailyBars extends StatelessWidget {
  const _DailyBars({required this.section, required this.month});

  final CurrencyOverview section;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final values = List<double>.filled(days, 0);
    for (final d in section.daily) {
      if (d.date.month == month.month && d.date.year == month.year) {
        values[d.date.day - 1] = d.amount.toDouble();
      }
    }
    final maxValue = values.fold<double>(0, math.max);
    final peak = values.indexOf(maxValue);
    final now = DateTime.now();
    final activeDays = values.where((v) => v > 0).length;
    final average = activeDays == 0
        ? 0.0
        : values.reduce((a, b) => a + b) / activeDays;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: '${i + 1}: ${values[i].toStringAsFixed(2)}',
                      child: Container(
                        height: maxValue == 0
                            ? 2
                            : math.max(2, 86 * values[i] / maxValue),
                        decoration: BoxDecoration(
                          color: values[i] == 0
                              ? colors.glassBorder
                              : (i == peak
                                    ? colors.accent
                                    : colors.accent.withValues(alpha: .45)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('1', style: TextStyle(fontSize: 11, color: colors.muted)),
            const Spacer(),
            if (month.year == now.year && month.month == now.month)
              Text(
                'today ${now.day}',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
            const Spacer(),
            Text('$days', style: TextStyle(fontSize: 11, color: colors.muted)),
          ],
        ),
        if (activeDays > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Avg ${Money.parse(average.toStringAsFixed(2)).display(currencyCode: section.currency)} on days you spent'
            ' · biggest day: ${peak + 1}',
            style: TextStyle(fontSize: 12.5, color: colors.muted),
          ),
        ],
      ],
    );
  }
}
