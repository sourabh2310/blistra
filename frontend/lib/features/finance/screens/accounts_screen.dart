/// Accounts tab and the create/edit account form.
library;

import 'package:flutter/material.dart';

import '../../../core/api/api_exception.dart';
import '../finance_controller.dart';
import '../finance_scope.dart';
import '../models.dart';
import 'form_helpers.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!controller.hasAccounts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('No accounts yet.'),
          ),
        for (final Account account in controller.accounts)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text(account.name),
              subtitle: Text(
                '${account.type.name} · ${account.currency}'
                '${account.isArchived ? ' · archived' : ''}',
              ),
              trailing: Text(
                account.balance.format(currencyCode: account.currency),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => AccountFormScreen(account: account),
                ));
              },
            ),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const AccountFormScreen(),
            ));
          },
          icon: const Icon(Icons.add),
          label: const Text('New account'),
        ),
      ],
    );
  }
}

class AccountFormScreen extends StatefulWidget {
  const AccountFormScreen({super.key, this.account});

  final Account? account;

  @override
  State<AccountFormScreen> createState() => _AccountFormScreenState();
}

class _AccountFormScreenState extends State<AccountFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _currency;
  late final TextEditingController _openingBalance;
  late final TextEditingController _notes;
  late AccountType _type;
  bool _saving = false;
  bool _archiving = false;
  String? _error;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final Account? account = widget.account;
    _name = TextEditingController(text: account?.name ?? '');
    _currency = TextEditingController(text: account?.currency ?? '');
    _openingBalance = TextEditingController(
        text: account?.openingBalance.toPlainString() ?? '');
    _notes = TextEditingController(text: account?.notes ?? '');
    _type = account?.type ?? AccountType.cash;
  }

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    _openingBalance.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save(FinanceController controller) async {
    if (widget.account?.isArchived ?? false) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEditing) {
        await controller.updateAccount(
          widget.account!.id,
          name: _name.text.trim(),
          type: _type,
          currency: _currency.text.trim(),
          openingBalance: _openingBalance.text.trim(),
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
      } else {
        await controller.addAccount(
          name: _name.text.trim(),
          type: _type,
          currency: _currency.text.trim(),
          openingBalance: _openingBalance.text.trim(),
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

  Future<void> _archive(FinanceController controller) async {
    setState(() {
      _archiving = true;
      _error = null;
    });
    try {
      await controller.archiveAccount(widget.account!.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _archiving = false;
          _error = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final FinanceController controller = FinanceScope.of(context);
    final bool archived = widget.account?.isArchived ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit account' : 'New account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (archived)
                  const Card(
                    color: Colors.amber,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'This account is archived and cannot be edited.',
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (String? v) => FormValidators.required(v, label: 'Name'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AccountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(
                    labelText: 'Type',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                  items: [
                    for (final AccountType type in AccountType.values)
                      DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      ),
                  ],
                  onChanged: archived
                      ? null
                      : (AccountType? value) {
                          if (value != null) {
                            setState(() => _type = value);
                          }
                        },
                ),
                const SizedBox(height: 16),
                CurrencyField(controller: _currency),
                const SizedBox(height: 16),
                AmountField(
                  controller: _openingBalance,
                  allowZero: true,
                  label: 'Opening balance',
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
                  onPressed: (_saving || archived)
                      ? null
                      : () => _save(controller),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Create account'),
                ),
                if (_isEditing && !archived) ...[
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _archiving ? null : () => _archive(controller),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: _archiving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Archive account'),
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