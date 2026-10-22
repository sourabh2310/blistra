/// Month at a glance: what you spent (your own share), today and last month,
/// the budget with a daily allowance, where it went, who owes whom, and the
/// latest expenses.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';

class OverviewTab extends StatelessWidget {
  const OverviewTab({
    super.key,
    required this.onOpenFriends,
    required this.onAddExpense,
    this.onOpenExpenses,
    this.onOpenExpense,
  });

  final VoidCallback onOpenFriends;
  final VoidCallback onAddExpense;

  /// Switches to the full Expenses tab.
  final VoidCallback? onOpenExpenses;
  final ValueChanged<Expense>? onOpenExpense;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<FinanceController>();
    final overview = controller.overview;
    final section = controller.primaryOverview;
    final currency = section?.currency ?? controller.currency;
    final meId = controller.me?.id;
    final recent = controller.expenses.take(5).toList();
    final hasSpending = section != null && section.byCategory.isNotEmpty;
    final showFriends = overview != null &&
        (overview.owedToYou.isNotEmpty ||
            overview.youOwe.isNotEmpty ||
            overview.pendingRequests > 0 ||
            overview.friendCount > 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
      children: [
        PagePad(
          _SummaryCard(
            section: section,
            currency: currency,
            isCurrentMonth: controller.isCurrentMonth,
            month: controller.month,
          ),
        ),
        if (!hasSpending)
          PagePad(
            EmptyCard(
              message: 'No expenses this month yet. Log what you spend, or '
                  'split a bill with a friend.',
              action: 'Add expense',
              onAction: onAddExpense,
            ),
            top: 12,
          )
        else ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Where it went'),
          PagePad(
            _WhereItWent(
              section: section,
              currency: currency,
            ),
          ),
        ],
        if (showFriends) ...[
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Friends',
            actionLabel: overview.pendingRequests > 0
                ? '${overview.pendingRequests} '
                    '${overview.pendingRequests == 1 ? 'request' : 'requests'} ›'
                : 'Settle ›',
            onAction: onOpenFriends,
          ),
          PagePad(
            Row(
              children: [
                Expanded(
                  child: _BalanceCard(
                    label: 'Owed to you',
                    amounts: overview.owedToYou,
                    owed: true,
                    onTap: onOpenFriends,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BalanceCard(
                    label: 'You owe',
                    amounts: overview.youOwe,
                    owed: false,
                    onTap: onOpenFriends,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Recent',
            actionLabel: onOpenExpenses == null ? null : 'All ›',
            onAction: onOpenExpenses,
          ),
          PagePad(
            GlassList(
              children: [
                for (final e in recent)
                  ExpenseTile(
                    expense: e,
                    meId: meId,
                    showDate: true,
                    onTap: onOpenExpense == null
                        ? null
                        : () => onOpenExpense!(e),
                  ),
              ],
            ),
          ),
        ],
        if (hasSpending) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Day by day'),
          PagePad(
            GlassCard(
              padding: const EdgeInsets.all(15),
              child: _DailyBars(section: section, month: controller.month),
            ),
          ),
        ],
        if (section != null && section.budgets.isNotEmpty) ...[
          const SizedBox(height: 24),
          SectionHeader(
            title: 'Budgets',
            actionLabel: 'Add ›',
            onAction: () => showBudgetSheet(context),
          ),
          PagePad(
            GlassList(
              children: [
                for (final b in section.budgets) _BudgetRow(budget: b),
              ],
            ),
          ),
        ],
        if ((overview?.currencies.length ?? 0) > 1) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Other currencies'),
          PagePad(
            GlassList(
              children: [
                for (final c in overview!.currencies.where(
                  (c) => c.currency != currency,
                ))
                  GlassRow(
                    leading: const IconWell(Icons.currency_exchange_rounded),
                    title: c.currency,
                    subtitle: 'Tap to make it your default',
                    trailing: _Amount(c.spent.display(currencyCode: c.currency)),
                    onTap: () => controller.setCurrency(c.currency),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        const PagePad(
          FinanceNote(
            'Spending includes your trip shares. Friend balances are '
            'separate from Groups.',
          ),
        ),
      ],
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        fontFeatures: BlistraText.tabular,
        color: colors.text,
      ),
    );
  }
}

/// Spent / today / last month, then the overall budget with a daily
/// allowance (or an offer to set one).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.section,
    required this.currency,
    required this.isCurrentMonth,
    required this.month,
  });

  final CurrencyOverview? section;
  final String currency;
  final bool isCurrentMonth;
  final DateTime month;

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
      trendColor = change > 0 ? oweTone(colors) : owedTone(colors);
    }
    final paidMore = section != null && section!.paid > section!.spent;

    return GlassCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Figure(
                  label: 'Spent',
                  value: spent.display(currencyCode: currency),
                ),
              ),
              if (isCurrentMonth) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Figure(
                    label: 'Today',
                    value: (section?.todaySpent ?? Money.zero())
                        .display(currencyCode: currency),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Figure(
                  label: 'Last month',
                  value: previous.display(currencyCode: currency),
                ),
              ),
            ],
          ),
          if (trend != null || paidMore) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 2,
              children: [
                if (trend != null)
                  Text(
                    trend,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: trendColor,
                    ),
                  ),
                if (paidMore)
                  Text(
                    'You paid ${section!.paid.display(currencyCode: currency)} in total',
                    style: TextStyle(fontSize: 11.5, color: colors.muted),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          if (budget != null)
            _BudgetLine(
              budget: budget,
              currency: currency,
              isCurrentMonth: isCurrentMonth,
              month: month,
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Set a monthly limit to see how you're tracking.",
                    style: TextStyle(fontSize: 12, color: colors.muted),
                  ),
                ),
                const SizedBox(width: 8),
                Pill('Set budget', onTap: () => showBudgetSheet(context)),
              ],
            ),
        ],
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  const _BudgetLine({
    required this.budget,
    required this.currency,
    required this.isCurrentMonth,
    required this.month,
  });

  final Budget budget;
  final String currency;
  final bool isCurrentMonth;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final used = (budget.usage * 100).round();
    final tone = budget.over
        ? colors.danger
        : budget.usage >= 0.7
            ? colors.warning
            : colors.accentText;
    final parts = <String>['$used% used'];
    if (budget.over) {
      parts.add(
        '${(budget.spent - budget.limit).display(currencyCode: currency)} over budget',
      );
    } else if (isCurrentMonth) {
      final today = DateTime.now().day;
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      // Days left including today, so the allowance covers today's spending.
      final daysLeft = math.max(1, lastDay - today + 1);
      final perDay = (budget.limit - budget.spent).toDouble() / daysLeft;
      parts
        ..add('$daysLeft ${daysLeft == 1 ? 'day' : 'days'} left')
        ..add('${displayDouble(perDay, currency)}/day to stay on budget');
    } else {
      parts.add(
        '${(budget.limit - budget.spent).display(currencyCode: currency)} left',
      );
    }
    return InkWell(
      onTap: () => showBudgetSheet(context, existing: budget),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUDGET · ${budget.spent.display(currencyCode: currency)} OF '
            '${budget.limit.display(currencyCode: currency)}',
            style: BlistraText.caption(colors.muted),
          ),
          const SizedBox(height: 6),
          ProgressLine(value: budget.usage, color: tone),
          const SizedBox(height: 5),
          Text(
            parts.join(' · '),
            style: TextStyle(
              fontSize: 11,
              color: budget.over ? colors.danger : colors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Top categories as labelled bars; expands to every category.
class _WhereItWent extends StatefulWidget {
  const _WhereItWent({required this.section, required this.currency});

  final CurrencyOverview section;
  final String currency;

  @override
  State<_WhereItWent> createState() => _WhereItWentState();
}

class _WhereItWentState extends State<_WhereItWent> {
  static const _top = 4;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final section = widget.section;
    final items = [...section.byCategory]
      ..sort((a, b) => b.amount.toDouble().compareTo(a.amount.toDouble()));
    final shown = _all ? items : items.take(_top).toList();
    final palette = [...colors.data, colors.accentText];
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(15, 7, 15, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < shown.length; i++)
            _CategoryBar(
              item: shown[i],
              total: section.spent,
              currency: widget.currency,
              color: palette[i % palette.length],
              budget: section.budgets
                  .where((b) => b.category == shown[i].category)
                  .firstOrNull,
            ),
          if (items.length > _top) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Pill(
                _all ? 'Show top $_top' : 'Show all ${items.length}',
                onTap: () => setState(() => _all = !_all),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.item,
    required this.total,
    required this.currency,
    required this.color,
    this.budget,
  });

  final CategoryAmount item;
  final Money total;
  final String currency;
  final Color color;
  final Budget? budget;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final share = total.isZero
        ? 0.0
        : item.amount.toDouble() / total.toDouble();
    final b = budget;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  b != null
                      ? '${item.category.label} · ${(b.usage * 100).toStringAsFixed(0)}% of ${b.limit.display(currencyCode: currency)}'
                      : '${item.category.label} · ${(share * 100).toStringAsFixed(0)}%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: b != null && b.over ? colors.danger : colors.muted,
                  ),
                ),
              ),
              _Amount(item.amount.display(currencyCode: currency)),
            ],
          ),
          const SizedBox(height: 6),
          ProgressLine(
            value: b != null ? b.usage : share,
            color: b != null && b.over ? colors.danger : color,
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.label,
    required this.amounts,
    required this.owed,
    required this.onTap,
  });

  final String label;
  final List<CurrencyAmount> amounts;
  final bool owed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Figure(
        label: label,
        value: amounts.isEmpty ? '—' : amounts.map((a) => a.display).join(' + '),
        color: amounts.isEmpty
            ? colors.muted
            : (owed ? owedTone(colors) : oweTone(colors)),
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
    final tone = budget.over
        ? colors.danger
        : budget.usage >= 0.7
            ? colors.warning
            : colors.accentText;
    return InkWell(
      onTap: () => showBudgetSheet(context, existing: budget),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
        child: Row(
          children: [
            IconWell(budget.category?.icon ?? Icons.savings_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          budget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: colors.text,
                          ),
                        ),
                      ),
                      Text(
                        '${budget.spent.display(currencyCode: budget.currency)} / ${budget.limit.display(currencyCode: budget.currency)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontFeatures: BlistraText.tabular,
                          color: budget.over ? colors.danger : colors.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ProgressLine(value: budget.usage, color: tone),
                ],
              ),
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
    final small = TextStyle(fontSize: 11, color: colors.muted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 72,
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
                            : math.max(2, 70 * values[i] / maxValue),
                        decoration: BoxDecoration(
                          color: values[i] == 0
                              ? colors.inkAt(0.12)
                              : (i == peak
                                    ? colors.accentText
                                    : colors.accentText.withValues(alpha: .45)),
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
            Text('1', style: small),
            const Spacer(),
            if (month.year == now.year && month.month == now.month)
              Text('today ${now.day}', style: small),
            const Spacer(),
            Text('$days', style: small),
          ],
        ),
        if (activeDays > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Avg ${displayDouble(average, section.currency)} on days you spent'
            ' · biggest day: ${peak + 1}',
            style: TextStyle(fontSize: 11.5, color: colors.muted),
          ),
        ],
      ],
    );
  }
}
