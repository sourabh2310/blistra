/// Everything shared with one person: balance, settle up, add an expense
/// together, and the combined history of expenses and repayments.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';

class FriendDetailScreen extends StatefulWidget {
  const FriendDetailScreen({super.key, required this.userId, this.initial});

  final String userId;
  final UserSummary? initial;

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  FriendDetail? _detail;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final controller = context.read<FinanceController>();
      if (controller.status == FinanceLoadStatus.idle) controller.loadAll();
      final detail = await controller.api.friendDetail(widget.userId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _push(Widget screen) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(value: context.read<FinanceController>(), child: screen),
    ));
    if (changed == true) await _load();
  }

  Future<void> _settle() async {
    final done = await showSettleUpSheet(context, friend: _detail!.friend);
    if (done == true) await _load();
  }

  Future<void> _remove() async {
    final name = _detail!.friend.user.displayName;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove $name?'),
        content: const Text(
            'You won\'t be able to add new shared expenses together. Past expenses and any open balance stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<FinanceController>().removeFriend(widget.userId);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _deleteSettlement(Settlement s) async {
    try {
      await context.read<FinanceController>().deleteSettlement(s);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final meId = context.watch<FinanceController>().me?.id;
    final detail = _detail;
    final user = detail?.friend.user ?? widget.initial;

    final items = <(DateTime, Object)>[
      if (detail != null) ...detail.expenses.map((e) => (e.spentOn, e as Object)),
      if (detail != null) ...detail.settlements.map((s) => (s.settledOn, s as Object)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            BlistraPageHeader(
              title: user?.displayName ?? 'Friend',
              subtitle: user == null ? null : '@${user.username}',
              showAvatar: false,
              actions: [
                if (detail != null && detail.friend.isFriend)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (_) => _remove(),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'remove', child: Text('Remove friend'))],
                    child: const IgnorePointer(
                      child: GlassIconButton(tooltip: null, icon: Icons.more_horiz, onTap: null),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: detail == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : Text(_error!, style: TextStyle(color: colors.muted)),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        children: [
                          GlassCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    UserAvatar(detail.friend.user, size: 52),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        balanceSentence(detail.friend.balances),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: balanceColor(detail.friend.balances, colors),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (!detail.friend.isFriend) ...[
                                  const SizedBox(height: 10),
                                  Text('Not friends any more — you can still settle up.',
                                      style: TextStyle(color: colors.muted, fontSize: 12.5)),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed: detail.friend.settled ? null : _settle,
                                        icon: const Icon(Icons.handshake_rounded),
                                        label: const Text('Settle up'),
                                      ),
                                    ),
                                    if (detail.friend.isFriend) ...[
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _push(ExpenseFormScreen(withFriend: detail.friend.user)),
                                          icon: const Icon(Icons.add_rounded),
                                          label: const Text('Add expense'),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SectionLabel('History'),
                          if (items.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('No shared expenses yet.',
                                  textAlign: TextAlign.center, style: TextStyle(color: colors.muted)),
                            )
                          else
                            GlassCard(
                              padding: const EdgeInsets.all(6),
                              child: Column(
                                children: [
                                  for (final (_, item) in items)
                                    if (item is Expense)
                                      ExpenseTile(
                                        expense: item,
                                        meId: meId,
                                        onTap: () => _push(ExpenseDetailScreen(expense: item)),
                                      )
                                    else if (item is Settlement)
                                      _SettlementTile(
                                        settlement: item,
                                        meId: meId,
                                        onDelete: item.editable ? () => _deleteSettlement(item) : null,
                                      ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({required this.settlement, required this.meId, this.onDelete});

  final Settlement settlement;
  final String? meId;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final iPaid = settlement.payer.id == meId;
    final who = iPaid ? 'You paid ${settlement.payee.displayName}' : '${settlement.payer.displayName} paid you';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: owedColor.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.handshake_rounded, color: owedColor),
      ),
      title: Text(who, style: TextStyle(fontWeight: FontWeight.w600, color: colors.text)),
      subtitle: Text([dayLabel(settlement.settledOn), if (settlement.note != null) settlement.note!].join(' · ')),
      trailing: Text(
        settlement.amount.display(currencyCode: settlement.currency),
        style: TextStyle(fontWeight: FontWeight.w700, color: colors.text),
      ),
      onLongPress: onDelete == null
          ? null
          : () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete this payment?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true) onDelete!();
            },
    );
  }
}
