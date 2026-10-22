/// Everything shared with one person: balance, settle up, add an expense
/// together, and the combined history of expenses and repayments.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';
import 'groups_tab.dart';
import 'payment_tile.dart';

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
  bool _busy = false;
  List<Map<String, dynamic>> _history = [];
  int _historyPage = 0;
  bool _moreHistory = false;

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
      final history = await controller.api.history(friendId: widget.userId);
      if (mounted) {
        setState(() {
          _detail = detail;
          _history = history;
          _historyPage = 0;
          _moreHistory = history.length == 100;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _push(Widget screen) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<FinanceController>(),
          child: screen,
        ),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _loadMoreHistory() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final rows = await context.read<FinanceController>().api.history(
        friendId: widget.userId,
        page: _historyPage + 1,
      );
      if (!mounted) return;
      setState(() {
        final ids = _history.map((h) => h['id']).toSet();
        _history.addAll(rows.where((h) => ids.add(h['id'])));
        _historyPage++;
        _moreHistory = rows.length == 100;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          'You won\'t be able to add new shared expenses together. Past expenses and any open balance stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<FinanceController>().removeFriend(widget.userId);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _deleteSettlement(Settlement s) async {
    try {
      await context.read<FinanceController>().deleteSettlement(s);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _decide(Settlement s, bool confirmed) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await context.read<FinanceController>().decideSettlement(
        s.id,
        confirmed: confirmed,
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final meId = context.watch<FinanceController>().me?.id;
    final detail = _detail;
    final user = detail?.friend.user ?? widget.initial;

    final items = <(DateTime, Object)>[
      if (detail != null)
        ...detail.expenses.map((e) => (e.spentOn, e as Object)),
      if (detail != null)
        ...detail.settlements.map((s) => (s.settledOn, s as Object)),
    ]..sort((a, b) => b.$1.compareTo(a.$1));

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: detail == null
          ? null
          : StickyActionBar(
              label: 'Settle up',
              onPressed: detail.friend.settled ? null : _settle,
              secondary: detail.friend.isFriend
                  ? OutlinedButton.icon(
                      onPressed: () => _push(
                        ExpenseFormScreen(withFriend: detail.friend.user),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add expense'),
                    )
                  : null,
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BlistraPageHeader(
              eyebrow: 'Friend',
              title: user?.displayName ?? 'Friend',
              subtitle: user == null ? null : '@${user.username}',
              showAvatar: false,
              actions: [
                if (detail != null && detail.friend.isFriend)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (_) => _remove(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'remove',
                        child: Text('Remove friend'),
                      ),
                    ],
                    child: const IgnorePointer(
                      child: GlassIconButton(
                        tooltip: null,
                        icon: Icons.more_horiz,
                        onTap: null,
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: detail == null
                  ? Center(
                      child: _error == null
                          ? const CircularProgressIndicator()
                          : Text(
                              _error!,
                              style: TextStyle(color: colors.muted),
                            ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(0, 10, 0, 24),
                        children: [
                          PagePad(
                            GlassCard(
                              padding: const EdgeInsets.all(15),
                              child: Row(
                                children: [
                                  UserAvatar(detail.friend.user, size: 48),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'BALANCE',
                                          style: BlistraText.caption(
                                            colors.muted,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          balanceSentence(
                                            detail.friend.balances,
                                          ),
                                          style: BlistraText.serif(
                                            19,
                                            balanceColor(
                                              detail.friend.balances,
                                              colors,
                                            ),
                                          ),
                                        ),
                                        if (!detail.friend.isFriend) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Not friends any more — you can still settle up.',
                                            style: TextStyle(
                                              color: colors.muted,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const SectionHeader(title: 'History'),
                          if (items.isEmpty)
                            const PagePad(
                              EmptyCard(message: 'No shared expenses yet.'),
                            )
                          else
                            PagePad(
                              GlassList(
                                children: [
                                  for (final (_, item) in items)
                                    if (item is Expense)
                                      ExpenseTile(
                                        expense: item,
                                        meId: meId,
                                        showDate: true,
                                        onTap: () => _push(
                                          ExpenseDetailScreen(expense: item),
                                        ),
                                      )
                                    else if (item is Settlement)
                                      PaymentTile(
                                        settlement: item,
                                        busy: _busy,
                                        onDecision: item.confirmable
                                            ? (yes) => _decide(item, yes)
                                            : null,
                                        onDelete: item.editable
                                            ? () => _deleteSettlement(item)
                                            : null,
                                      ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          const SectionHeader(title: 'Change history'),
                          PagePad(
                            FinanceHistoryList(entries: _history, meId: meId),
                          ),
                          if (_moreHistory)
                            Center(
                              child: TextButton(
                                onPressed: _busy ? null : _loadMoreHistory,
                                child: const Text('Load more changes'),
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
