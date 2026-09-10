/// Overview tab: per-currency summary, account balances, spending by
/// category and recent transactions for the selected month.
library;

import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../finance_controller.dart';
import '../finance_scope.dart';
import '../models.dart';
import 'account_form_screen.dart';
import 'transaction_form_screen.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);

    if (!controller.hasAccounts) {
      return const _EmptyState();
    }

    final List<Widget> children = <Widget>[
      for (final SummaryCurrencySection section
          in controller.summary?.currencies ?? const <SummaryCurrencySection>[])
        _SummaryCard(section: section),
      const SizedBox(height: 16),
      const _SectionHeader(title: 'Accounts', icon: Icons.account_balance_wallet),
      for (final Account account in controller.accounts)
        _AccountTile(account: account),
      if (controller.accounts.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('No accounts yet.'),
        ),
      const SizedBox(height: 16),
      const _SectionHeader(title: 'Recent transactions', icon: Icons.receipt_long),
      for (final FinanceTransaction transaction
          in controller.transactions.take(8))
        _TransactionTile(transaction: transaction),
      if (controller.transactions.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'No transactions this month.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      const SizedBox(height: 16),
      for (final SummaryCurrencySection section
          in controller.summary?.currencies ?? const <SummaryCurrencySection>[])
        if (section.spendingByCategory.isNotEmpty) ...[
          _SectionHeader(
            title: 'Spending by category · ${section.currency}',
            icon: Icons.pie_chart_outline,
          ),
          for (final SummaryCategorySpend spend in section.spendingByCategory)
            _SpendTile(spend: spend, currency: section.currency),
        ],
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.section});

  final SummaryCurrencySection section;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(section.currency,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  'Net ${section.net.format(currencyCode: section.currency)}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: section.net < Money.zero()
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Row(
              label: 'Income',
              value: section.income.format(currencyCode: section.currency),
              color: theme.colorScheme.primary,
            ),
            _Row(
              label: 'Expense',
              value: section.expense.format(currencyCode: section.currency),
              color: theme.colorScheme.error,
            ),
            _Row(
              label: 'Transferred in',
              value: section.transferIn.format(currencyCode: section.currency),
              color: theme.colorScheme.tertiary,
            ),
            _Row(
              label: 'Transferred out',
              value: section.transferOut.format(currencyCode: section.currency),
              color: theme.colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(_typeIcon(account.type)),
        ),
        title: Text(account.name),
        subtitle: Text(_typeLabel(account.type)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              account.balance.format(currencyCode: account.currency),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (account.isArchived)
              Text(
                'Archived',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.outline),
              ),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => AccountFormScreen(account: account),
          ));
        },
      ),
    );
  }

  static String _typeIcon(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank';
      case AccountType.savings:
        return 'Sav';
      case AccountType.creditCard:
        return 'CC';
      case AccountType.wallet:
        return 'Wlt';
      case AccountType.other:
        return 'Otr';
    }
  }

  static String _typeLabel(AccountType type) =>
      type.name.toUpperCase();
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool income = transaction.isIncome;
    return ListTile(
      dense: true,
      leading: Icon(
        income ? Icons.arrow_downward : Icons.arrow_upward,
        color: income ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
      title: Text(transaction.description ?? transaction.categoryName),
      subtitle: Text(
        '${transaction.categoryName} · ${transaction.accountName}',
      ),
      trailing: Text(
        ('${income ? '+' : '-'}${transaction.amount.format(currencyCode: transaction.currency)}'),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: income ? theme.colorScheme.primary : theme.colorScheme.error,
        ),
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TransactionFormScreen(transaction: transaction),
        ));
      },
    );
  }
}

class _SpendTile extends StatelessWidget {
  const _SpendTile({required this.spend, required this.currency});

  final SummaryCategorySpend spend;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.label_outline),
      title: Text(spend.categoryName),
      trailing: Text(spend.amount.format(currencyCode: currency)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              'No accounts yet.\nCreate your first account to start tracking money.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const AccountFormScreen(),
                ));
              },
              icon: const Icon(Icons.add),
              label: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}