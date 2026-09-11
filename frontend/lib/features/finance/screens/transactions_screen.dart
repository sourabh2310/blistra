/// Transactions tab (month-scoped list with light client-side filters) and
/// the create/edit transaction form.
library;

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../finance_controller.dart';
import '../finance_scope.dart';
import '../models.dart';
import 'form_helpers.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  TransactionType? _typeFilter;
  String? _accountFilter;

  List<FinanceTransaction> _filtered(FinanceController controller) {
    return controller.transactions
        .where((FinanceTransaction t) {
          if (_typeFilter != null && t.type != _typeFilter) {
            return false;
          }
          if (_accountFilter != null && t.accountId != _accountFilter) {
            return false;
          }
          return true;
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);
    final List<FinanceTransaction> items = _filtered(controller);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<TransactionType?>(
                  initialValue: _typeFilter,
                  decoration: InputDecoration(
                    labelText: 'Type',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All types')),
                    DropdownMenuItem(
                        value: TransactionType.income, child: Text('Income')),
                    DropdownMenuItem(
                        value: TransactionType.expense, child: Text('Expense')),
                  ],
                  onChanged: (TransactionType? value) =>
                      setState(() => _typeFilter = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _accountFilter,
                  decoration: InputDecoration(
                    labelText: 'Account',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All accounts')),
                    for (final Account account in controller.activeAccounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _accountFilter = value),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? const Center(child: Text('No transactions this month.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (BuildContext context, int index) {
                    final FinanceTransaction t = items[index];
                    return _TransactionRow(transaction: t);
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const TransactionFormScreen(),
                ));
              },
              icon: const Icon(Icons.add),
              label: const Text('New transaction'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool income = transaction.isIncome;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(
            income ? Icons.arrow_downward : Icons.arrow_upward,
            color: income ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
        ),
        title: Text(transaction.description ?? transaction.categoryName),
        subtitle: Text(
          '${transaction.categoryName} · ${transaction.accountName}',
        ),
        trailing: Text(
          '${income ? '+' : '-'}'
          '${transaction.amount.format(currencyCode: transaction.currency)}',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: income ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
        ),
        onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => TransactionFormScreen(transaction: transaction),
          ));
        },
      ),
    );
  }
}

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, this.transaction});

  final FinanceTransaction? transaction;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _notes;
  String? _accountId;
  String? _categoryId;
  late TransactionType _type;
  late DateTime _occurredAt;
  bool _saving = false;
  bool _deleting = false;
  String? _error;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final FinanceTransaction? tx = widget.transaction;
    _accountId = tx?.accountId;
    _categoryId = tx?.categoryId;
    _type = tx?.type ?? TransactionType.expense;
    _occurredAt = tx?.occurredAt ?? DateTime.now();
    _amount = TextEditingController(text: tx?.amount.toPlainString() ?? '');
    _description = TextEditingController(text: tx?.description ?? '');
    _notes = TextEditingController(text: tx?.notes ?? '');
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<Category> _categoriesFor(FinanceController controller) {
    final catType = _type == TransactionType.income ? CategoryType.income : CategoryType.expense;
    return controller.categoriesOfType(catType);
  }

  Future<void> _save(FinanceController controller) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_accountId == null || _categoryId == null) {
      setState(() {
        _error = 'Select an account and a category';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await controller.updateTransaction(
          widget.transaction!.id,
          accountId: _accountId!,
          categoryId: _categoryId!,
          type: _type,
          amount: _amount.text.trim(),
          occurredAt: _occurredAt,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await controller.addTransaction(
          accountId: _accountId!,
          categoryId: _categoryId!,
          type: _type,
          amount: _amount.text.trim(),
          occurredAt: _occurredAt,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _delete(FinanceController controller) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Delete transaction?'),
            content: const Text('The transaction will be removed and account '
                'balances will be recalculated.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      return;
    }
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await controller.deleteTransaction(widget.transaction!.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);

    if (_categoryId != null &&
        controller.categoryById(_categoryId!)?.type != _type) {
      _categoryId = null;
    }
    final List<Category> availableCategories = _categoriesFor(controller);
    if (_categoryId != null &&
        !availableCategories.any((Category c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(_isEditing ? 'Edit transaction' : 'New transaction')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _type == TransactionType.expense
                      ? TransactionType.expense.name
                      : TransactionType.income.name,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.swap_vert),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'income',
                      child: Text('Income'),
                    ),
                    DropdownMenuItem(
                      value: 'expense',
                      child: Text('Expense'),
                    ),
                  ],
                  onChanged: (String? value) => setState(() {
                    _type = value == 'income'
                        ? TransactionType.income
                        : TransactionType.expense;
                    _categoryId = null;
                  }),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _accountId,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: [
                    for (final Account account in controller.activeAccounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} (${account.currency})',
                        ),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _accountId = value),
                  validator: (_) => _accountId == null
                      ? 'Select an account'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  items: [
                    for (final Category category in availableCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _categoryId = value),
                  validator: (_) => _categoryId == null
                      ? 'Select a category'
                      : null,
                ),
                const SizedBox(height: 16),
                AmountField(controller: _amount),
                const SizedBox(height: 16),
                AppDateField(
                  label: 'Date',
                  value: _occurredAt,
                  onChanged: (DateTime value) =>
                      setState(() => _occurredAt = value),
                  toDate: DateTime.now(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.short_text_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : () => _save(controller),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Add transaction'),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _deleting ? null : () => _delete(controller),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: _deleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Delete transaction'),
                  ),
                ],
                ],
              ),
            ),
          ),
        ),
      );
  }
}

DateTime _firstOfMonth(DateTime value) => DateTime(value.year, value.month);