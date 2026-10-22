/// One expense: amount, who paid, each person's share, and (for its
/// creator) edit and delete.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
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
      final loaded = await controller.api.expense(
        widget.expenseId ?? _expense!.id,
      );
      if (controller.status == FinanceLoadStatus.idle) controller.loadAll();
      if (mounted) setState(() => _expense = loaded);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _edit() async {
    final controller = context.read<FinanceController>();
    TripGroupDetail? group;
    if (_expense!.groupId != null) {
      try {
        group = await controller.api.group(_expense!.groupId!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(friendlyError(e))));
        }
        return;
      }
      if (!mounted) return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: ExpenseFormScreen(
            existing: _expense,
            groupId: group?.group.id,
            groupMembers: group?.accepted,
            groupCurrency: group?.group.currency,
          ),
        ),
      ),
    );
    if (saved == true) await _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text(
          _expense!.isShared
              ? 'It will be removed for everyone in the split and balances will update.'
              : 'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: BlistraColors.resolve(context).danger,
            ),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final e = _expense;
    final meId = context.watch<FinanceController>().me?.id;
    String money(Money m) => m.display(currencyCode: e!.currency);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            BlistraPageHeader(
              eyebrow: e == null ? 'Expense' : e.category.label,
              title: e?.description ?? 'Expense',
              subtitle: e == null
                  ? null
                  : '${DateFormat('EEE, d MMM yyyy').format(e.spentOn)} · '
                        '${e.isShared ? '${e.paidBy.id == meId ? 'You' : e.paidBy.displayName} paid · split ${e.splitType.label.toLowerCase()}' : 'Personal expense'}',
              showAvatar: false,
              actions: [
                if (e != null && e.editable) ...[
                  GlassIconButton(
                    tooltip: 'Edit expense',
                    icon: Icons.edit_rounded,
                    onTap: _busy ? null : _edit,
                  ),
                  GlassIconButton(
                    tooltip: 'Delete expense',
                    icon: Icons.delete_outline_rounded,
                    onTap: _busy ? null : _delete,
                  ),
                ],
              ],
            ),
            Expanded(
              child: e == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : Text(
                              _error!,
                              style: TextStyle(color: colors.muted),
                            ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
                      children: [
                        StatStrip(
                          stats: [
                            StatData(
                              label: 'Total',
                              value: money(e.amount),
                              sub: e.currency,
                              icon: e.category.icon,
                            ),
                            if (e.isShared)
                              StatData(
                                label: 'Your share',
                                value: money(e.myShare),
                                sub: '${e.shares.length} in the split',
                              ),
                            if (e.isShared && !e.myBalance.isZero)
                              StatData(
                                label: e.myBalance.isNegative
                                    ? 'You borrowed'
                                    : 'You lent',
                                value: money(e.myBalance.abs()),
                                sub: e.myBalance.isNegative
                                    ? 'You owe this back'
                                    : 'Owed back to you',
                              ),
                          ],
                        ),
                        if (e.isShared) ...[
                          const SizedBox(height: 24),
                          const SectionHeader(title: 'Shares'),
                          PagePad(
                            GlassList(
                              children: [
                                for (final s in e.shares)
                                  GlassRow(
                                    leading: UserAvatar(s.user),
                                    title: s.user.id == meId
                                        ? 'You'
                                        : s.user.displayName,
                                    subtitle: [
                                      if (s.user.id == e.paidBy.id)
                                        'paid ${money(e.amount)}',
                                      if (e.splitType == SplitType.percent &&
                                          s.value != null)
                                        '${s.value}%',
                                      if (e.splitType == SplitType.shares &&
                                          s.value != null)
                                        '${s.value} share(s)',
                                    ].join(' · '),
                                    trailing: Text(
                                      money(s.amount),
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: BlistraText.tabular,
                                        color: colors.text,
                                      ),
                                    ),
                                  ),
                                if (!e.shares.any(
                                  (s) => s.user.id == e.paidBy.id,
                                ))
                                  GlassRow(
                                    leading: UserAvatar(e.paidBy),
                                    title: e.paidBy.id == meId
                                        ? 'You'
                                        : e.paidBy.displayName,
                                    subtitle: 'paid ${money(e.amount)}',
                                    trailing: const RowMeta('—'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        if (e.notes != null && e.notes!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const SectionHeader(title: 'Notes'),
                          PagePad(
                            GlassCard(
                              padding: const EdgeInsets.all(15),
                              child: Text(
                                e.notes!,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: colors.text,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          e.createdBy.id == meId
                              ? 'Added by you'
                              : 'Added by ${e.createdBy.displayName}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: colors.muted, fontSize: 11.5),
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
