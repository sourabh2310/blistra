import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';
import 'expense_detail_screen.dart';
import 'expense_form_screen.dart';
import 'payment_tile.dart';

/// Groups are opt-in: invitees see an invitation, never the group's ledger.
class GroupsTab extends StatefulWidget {
  const GroupsTab({super.key});
  @override
  State<GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<GroupsTab> {
  List<TripGroup>? _groups;
  String? _error;
  bool _busy = false;
  FinanceController get controller => context.read<FinanceController>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final groups = await controller.api.groups();
      if (mounted) {
        setState(() {
          _groups = groups;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final name = await _ask(
      context,
      'Create a trip or group',
      'Group name (up to 120 characters)',
    );
    if (name == null || !mounted) return;
    await _run(() async {
      await controller.api.createGroup(name, controller.currency);
    });
  }

  Future<void> _open(TripGroup g) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: GroupDetailScreen(group: g),
        ),
      ),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        FilledButton.icon(
          onPressed: _busy ? null : _create,
          icon: const Icon(Icons.group_add_outlined),
          label: const Text('Create trip / group'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Keep each trip separate. Invite people by username; they choose whether to join.',
          ),
        ),
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
        if (_groups == null && _error == null)
          const Center(child: CircularProgressIndicator()),
        if (_groups?.isEmpty == true) const Text('No groups yet.'),
        for (final g in _groups ?? <TripGroup>[])
          Card(
            child: ListTile(
              title: Text(g.name),
              subtitle: Text(
                '${g.currency} · ${g.invited ? 'Invitation' : 'Joined'}',
              ),
              onTap: g.invited ? null : () => _open(g),
              trailing: g.invited
                  ? Wrap(
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _run(
                                  () => controller.api.acceptGroup(g.id),
                                ),
                          child: const Text('Join'),
                        ),
                        IconButton(
                          tooltip: 'Decline invitation',
                          onPressed: _busy
                              ? null
                              : () =>
                                    _run(() => controller.api.leaveGroup(g.id)),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    )
                  : const Icon(Icons.chevron_right),
            ),
          ),
      ],
    ),
  );
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({super.key, required this.group});
  final TripGroup group;
  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  TripGroupDetail? _detail;
  List<Expense> _expenses = [];
  List<Settlement> _payments = [];
  List<Map<String, dynamic>> _history = [];
  bool _busy = false, _last = true;
  int _page = 0;
  String? _error;
  FinanceController get controller => context.read<FinanceController>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = controller.api, id = widget.group.id;
      final results = await Future.wait<Object>([
        api.group(id),
        api.groupExpenses(id),
        api.groupPayments(id),
        api.history(groupId: id),
      ]);
      if (!mounted) return;
      final expenses = results[1] as ExpensePage;
      setState(() {
        _detail = results[0] as TripGroupDetail;
        _expenses = expenses.items;
        _last = expenses.last;
        _page = 0;
        _payments = results[2] as List<Settlement>;
        _history = results[3] as List<Map<String, dynamic>>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite() async {
    final username = await _ask(context, 'Invite a member', 'Exact username');
    if (username != null && mounted) {
      await _run(() => controller.api.inviteToGroup(widget.group.id, username));
    }
  }

  Future<void> _expense() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: controller,
          child: ExpenseFormScreen(
            groupId: widget.group.id,
            groupMembers: _detail!.accepted,
            groupCurrency: widget.group.currency,
          ),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _payment(UserSummary other) async {
    // Group balances are net positions, not a pairwise debt recommendation.
    await showSettleUpSheet(
      context,
      groupId: widget.group.id,
      currency: widget.group.currency,
      friend: Friend(user: other, isFriend: false, balances: const []),
    );
    if (mounted) await _load();
  }

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave this group?'),
        content: const Text(
          'Shared records and balances stay. You will need another invitation to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _run(() async {
        await controller.api.leaveGroup(widget.group.id);
        if (mounted) Navigator.pop(context);
      });
    }
  }

  Future<void> _more() async {
    setState(() => _busy = true);
    try {
      final page = await controller.api.groupExpenses(
        widget.group.id,
        page: _page + 1,
      );
      if (mounted) {
        setState(() {
          _expenses.addAll(page.items);
          _page++;
          _last = page.last;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail, me = controller.me?.id;
    final owner = detail?.group.ownerId == me;
    final names = {
      for (final m in detail?.members ?? <TripMember>[])
        m.user.id: m.user.displayName,
    };
    return Scaffold(
      appBar: AppBar(title: Text(detail?.group.name ?? widget.group.name)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_error != null) ...[
              Text(_error!),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
            if (detail == null && _error == null)
              const Center(child: CircularProgressIndicator()),
            if (detail != null) ...[
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _expense,
                    icon: const Icon(Icons.add),
                    label: const Text('Add expense'),
                  ),
                  if (owner)
                    OutlinedButton(
                      onPressed: _busy ? null : _invite,
                      child: const Text('Invite member'),
                    ),
                  if (!owner)
                    TextButton(
                      onPressed: _busy ? null : _leave,
                      child: const Text('Leave group'),
                    ),
                ],
              ),
              const SectionLabel('Group balances'),
              const Text(
                'Positive: owed to this person. Negative: this person owes the group. Currencies stay separate.',
              ),
              if (detail.balances.isEmpty)
                const ListTile(title: Text('All settled up')),
              for (final b in detail.balances)
                ListTile(
                  title: Text(names[b.userId] ?? 'Former member'),
                  trailing: Text(b.amount.display(currencyCode: b.currency)),
                ),
              const SectionLabel('Members'),
              for (final m in detail.members)
                ListTile(
                  title: Text(m.user.displayName),
                  subtitle: Text(
                    '@${m.user.username} · ${m.owner ? 'Owner' : m.status.toLowerCase()}',
                  ),
                  trailing: m.status != 'ACCEPTED' || m.user.id == me
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (action) async {
                            if (action == 'pay') {
                              await _payment(m.user);
                            } else {
                              await _run(
                                () => controller.api.transferGroup(
                                  widget.group.id,
                                  m.user.id,
                                ),
                              );
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'pay',
                              child: Text('Record payment'),
                            ),
                            if (owner)
                              const PopupMenuItem(
                                value: 'owner',
                                child: Text('Make group owner'),
                              ),
                          ],
                        ),
                ),
              const SectionLabel('Expenses'),
              if (_expenses.isEmpty)
                const Text('Add the first expense for this trip.'),
              for (final e in _expenses)
                ExpenseTile(
                  expense: e,
                  meId: me,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: controller,
                          child: ExpenseDetailScreen(expense: e),
                        ),
                      ),
                    );
                    if (mounted) await _load();
                  },
                ),
              if (!_last)
                TextButton(
                  onPressed: _busy ? null : _more,
                  child: const Text('Load more expenses'),
                ),
              const SectionLabel('Payments (latest 200)'),
              const Text(
                'Recorded payments change balances only after the other participant confirms.',
              ),
              for (final s in _payments)
                PaymentTile(
                  settlement: s,
                  busy: _busy,
                  onDelete: s.editable
                      ? () => _run(() => controller.deleteSettlement(s))
                      : null,
                  onDecision: s.confirmable
                      ? (yes) => _run(
                          () =>
                              controller.decideSettlement(s.id, confirmed: yes),
                        )
                      : null,
                ),
              const SectionLabel('Change history (latest 100)'),
              FinanceHistoryList(entries: _history, meId: me),
            ],
          ],
        ),
      ),
    );
  }
}

class FinanceHistoryList extends StatelessWidget {
  const FinanceHistoryList({super.key, required this.entries, this.meId});
  final List<Map<String, dynamic>> entries;
  final String? meId;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (entries.isEmpty)
        const ListTile(title: Text('No changes recorded yet.')),
      for (final h in entries)
        ListTile(
          title: Text('${h['entityType']} · ${h['action']}'),
          subtitle: Text(
            '${h['actorId'] == meId ? 'You' : 'Participant'} · ${h['recordedAt']}',
          ),
          trailing: Text(
            '${h['currency']} ${h['beforeAmount'] == null ? '' : '${h['beforeAmount']} → '}${h['afterAmount'] ?? 'removed'}',
          ),
        ),
    ],
  );
}

Future<String?> _ask(BuildContext context, String title, String label) async {
  final input = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: input,
        autofocus: true,
        maxLength: 120,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (input.text.trim().isNotEmpty) {
              Navigator.pop(c, input.text.trim());
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  // The dialog's exit animation may still use the controller briefly.
  Future<void>.delayed(const Duration(seconds: 1), input.dispose);
  return result;
}
