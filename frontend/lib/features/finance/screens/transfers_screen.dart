/// Transfers tab (month-scoped list) and the create-transfer form.
///
/// Transfers move money between two of the user's accounts; they never
/// appear as income or expense, so they are tracked as first-class records.
library;

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../finance_controller.dart';
import '../finance_scope.dart';
import '../models.dart';
import 'form_helpers.dart';

class TransfersScreen extends StatelessWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);

    return Column(
      children: [
        Expanded(
          child: controller.transfers.isEmpty
              ? const Center(child: Text('No transfers this month.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.transfers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (BuildContext context, int index) {
                    final FinanceTransfer transfer = controller.transfers[index];
                    return _TransferCard(transfer: transfer);
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
                  builder: (_) => const TransferFormScreen(),
                ));
              },
              icon: const Icon(Icons.add),
              label: const Text('New transfer'),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.transfer});

  final FinanceTransfer transfer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.currency_exchange),
        title: Text(
          '${transfer.sourceAccountName} → ${transfer.destinationAccountName}',
        ),
        subtitle: Text('${transfer.note ?? ''}'
            .isEmpty
            ? 'Moved between your accounts'
            : transfer.note!),
        trailing: Text(
          transfer.amount.format(currencyCode: transfer.currency),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        onTap: () => _showDetail(context, transfer),
      ),
    );
  }

  Future<void> _showDetail(
    BuildContext context,
    FinanceTransfer transfer,
  ) async {
    final FinanceController controller = FinanceScope.of(context);
    final bool? deleted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Transfer · ${transfer.amount.format(currencyCode: transfer.currency)}'),
        content: Text(
          'From ${transfer.sourceAccountName}\n'
          'To ${transfer.destinationAccountName}\n'
          'On ${_date(transfer.transferredAt)}${transfer.note != null ? '\n\n${transfer.note}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (deleted ?? false) {
      try {
        await controller.deleteTransfer(transfer.id);
      } on ApiException catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(error.toString())));
        }
      }
    }
  }

  static String _date(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class TransferFormScreen extends StatefulWidget {
  const TransferFormScreen({super.key});

  @override
  State<TransferFormScreen> createState() => _TransferFormScreenState();
}

class _TransferFormScreenState extends State<TransferFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  String? _sourceAccountId;
  String? _destinationAccountId;
  late DateTime _transferredAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _transferredAt = DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(FinanceController controller) async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_sourceAccountId == null || _destinationAccountId == null) {
      setState(() {
        _error = 'Select both source and destination account';
      });
      return;
    }
    if (_sourceAccountId == _destinationAccountId) {
      setState(() {
        _error = 'Source and destination must be different accounts';
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await controller.addTransfer(
        sourceAccountId: _sourceAccountId!,
        destinationAccountId: _destinationAccountId!,
        amount: _amount.text.trim(),
        transferredAt: _transferredAt,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
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

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);
    final List<Account> accounts = controller.activeAccounts;

    return Scaffold(
      appBar: AppBar(title: const Text('New transfer')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String?>(
                  initialValue: _sourceAccountId,
                  decoration: const InputDecoration(
                    labelText: 'From account',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.logout),
                  ),
                  items: [
                    for (final Account account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} (${account.currency})',
                        ),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _sourceAccountId = value),
                  validator: (_) =>
                      _sourceAccountId == null ? 'Select source account' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _destinationAccountId,
                  decoration: const InputDecoration(
                    labelText: 'To account',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.login),
                  ),
                  items: [
                    for (final Account account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          '${account.name} (${account.currency})',
                        ),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setState(() => _destinationAccountId = value),
                  validator: (_) => _destinationAccountId == null
                      ? 'Select destination account'
                      : null,
                ),
                const SizedBox(height: 16),
                AmountField(controller: _amount),
                const SizedBox(height: 16),
                AppDateField(
                  label: 'Date',
                  value: _transferredAt,
                  onChanged: (DateTime value) =>
                      setState(() => _transferredAt = value),
                  toDate: DateTime.now(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
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
                      : const Text('Add transfer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}