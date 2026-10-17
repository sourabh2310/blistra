/// One expense: amount, who paid, each person's share, and (for its
/// creator) edit and delete.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({super.key, this.expense, this.expenseId})
      : assert(expense != null || expenseId != null);

  final Expense? expense;

  /// Loads the expense by id (e.g. from search) when [expense] is null.
  final String? expenseId;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  Expense? _expense;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _expense = widget.expense;
    if (_expense == null) _load();
  }

  Future<void> _load() async {
    try {
      final controller = context.read<FinanceController>();
      final loaded = await controller.api.expense(widget.expenseId ?? _expense!.id);
      if (controller.status == FinanceLoadStatus.idle) controller.loadAll();
      if (mounted) setState(() => _expense = loaded);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<FinanceController>(),
        child: ExpenseFormScreen(existing: _expense),
      ),
    ));
    if (saved == true) await _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(_expense!.isShared
            ? 'It will be removed for everyone in the split and balances will update.'
            : 'This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: oweColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<FinanceController>().deleteExpense(_expense!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final e = _expense;
    final meId = context.watch<FinanceController>().me?.id;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            BlistraPageHeader(
              title: 'Expense',
              showAvatar: false,
              actions: [
                if (e != null && e.editable) ...[
                  GlassIconButton(tooltip: 'Edit expense', icon: Icons.edit_rounded, onTap: _busy ? null : _edit),
                  GlassIconButton(
                      tooltip: 'Delete expense', icon: Icons.delete_outline_rounded, onTap: _busy ? null : _delete),
                ],
              ],
            ),
            Expanded(
              child: e == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : Text(_error!, style: TextStyle(color: colors.muted)),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CategoryAvatar(e.category, size: 48),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.description,
                                            style: TextStyle(
                                                fontSize: 19, fontWeight: FontWeight.w700, color: colors.text)),
                                        Text('${e.category.label} · ${DateFormat('d MMM yyyy').format(e.spentOn)}',
                                            style: TextStyle(color: colors.muted)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Text(e.amount.display(currencyCode: e.currency),
                                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: colors.text)),
                              const SizedBox(height: 4),
                              Text(
                                e.isShared
                                    ? '${e.paidBy.id == meId ? 'You' : e.paidBy.displayName} paid · split ${e.splitType.label.toLowerCase()}'
                                    : 'Personal expense',
                                style: TextStyle(color: colors.muted),
                              ),
                              if (e.isShared && !e.myBalance.isZero) ...[
                                const SizedBox(height: 10),
                                Text(
                                  e.myBalance.isNegative
                                      ? 'You borrowed ${e.myBalance.abs().display(currencyCode: e.currency)}'
                                      : 'You lent ${e.myBalance.display(currencyCode: e.currency)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: e.myBalance.isNegative ? oweColor : owedColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (e.isShared) ...[
                          const SectionLabel('Shares'),
                          GlassCard(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                for (final s in e.shares)
                                  ListTile(
                                    leading: UserAvatar(s.user),
                                    title: Text(s.user.id == meId ? 'You' : s.user.displayName),
                                    subtitle: Text(
                                      [
                                        if (s.user.id == e.paidBy.id) 'paid ${e.amount.display(currencyCode: e.currency)}',
                                        if (e.splitType == SplitType.percent && s.value != null) '${s.value}%',
                                        if (e.splitType == SplitType.shares && s.value != null) '${s.value} share(s)',
                                      ].join(' · '),
                                    ),
                                    trailing: Text(s.amount.display(currencyCode: e.currency),
                                        style: TextStyle(fontWeight: FontWeight.w700, color: colors.text)),
                                  ),
                                if (!e.shares.any((s) => s.user.id == e.paidBy.id))
                                  ListTile(
                                    leading: UserAvatar(e.paidBy),
                                    title: Text(e.paidBy.id == meId ? 'You' : e.paidBy.displayName),
                                    subtitle: Text('paid ${e.amount.display(currencyCode: e.currency)}'),
                                    trailing: Text('—', style: TextStyle(color: colors.muted)),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (e.notes != null && e.notes!.isNotEmpty) ...[
                          const SectionLabel('Notes'),
                          GlassCard(child: Text(e.notes!, style: TextStyle(color: colors.text))),
                        ],
                        const SizedBox(height: 14),
                        Text(
                          e.createdBy.id == meId ? 'Added by you' : 'Added by ${e.createdBy.displayName}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.muted, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
