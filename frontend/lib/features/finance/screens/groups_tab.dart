import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../../../core/widgets/design_system.dart';
import '../../../core/widgets/page_header.dart';
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
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final groups = _groups ?? <TripGroup>[];
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          PagePad(
            StatusCard(
              caption: 'Trips & groups',
              title: 'Split a trip together',
              subtitle:
                  'Keep each trip separate. Invite people by username; they choose whether to join.',
              leading: const IconWell(Icons.luggage_rounded, size: 44),
              trailing: Pill(
                'Create',
                onTap: _busy ? null : _create,
              ),
              onTap: _busy ? null : _create,
            ),
          ),
          if (_error != null)
            PagePad(
              EmptyCard(message: _error!, action: 'Retry', onAction: _load),
              top: 12,
            ),
          if (_groups == null && _error == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_groups?.isEmpty == true)
            const PagePad(EmptyCard(message: 'No groups yet.'), top: 12),
          if (groups.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeader(title: 'Your groups'),
            PagePad(
              GlassList(
                children: [
                  for (final g in groups)
                    GlassRow(
                      leading: IconWell(
                        g.invited
                            ? Icons.mail_outline_rounded
                            : g.archived
                            ? Icons.inventory_2_outlined
                            : Icons.groups_rounded,
                        color: g.invited ? colors.accentText : null,
                      ),
                      title: g.name,
                      subtitle:
                          '${g.currency} · ${g.invited
                              ? 'Invitation'
                              : g.archived
                              ? 'Archived'
                              : 'Joined'}',
                      onTap: g.invited ? null : () => _open(g),
                      trailing: g.invited
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Pill(
                                  'Join',
                                  onTap: _busy
                                      ? null
                                      : () => _run(
                                          () => controller.api.acceptGroup(g.id),
                                        ),
                                ),
                                IconButton(
                                  tooltip: 'Decline invitation',
                                  color: colors.muted,
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => controller.api.leaveGroup(g.id),
                                        ),
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ],
                            )
                          : Icon(
                              Icons.chevron_right_rounded,
                              color: colors.muted,
                            ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
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
  int _paymentPage = 0, _historyPage = 0;
  bool _morePayments = false, _moreHistory = false;
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
        _paymentPage = _historyPage = 0;
        _morePayments = _payments.length == 200;
        _moreHistory = _history.length == 100;
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

  Future<void> _export() async {
    final consent = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Export trip ledger?'),
        content: const Text(
          'The JSON download includes members, expense notes, payments and change history. '
          'It stays in your chosen folder after logout. Keep it private.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      final ledger = await controller.api.exportGroup(widget.group.id);
      if (!mounted) return;
      await FilePicker.platform.saveFile(
        dialogTitle: 'Save trip ledger',
        fileName: 'blistra-trip-${widget.group.id}.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(ledger)),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
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

  Future<void> _moreLedger({required bool payments}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (payments) {
        final rows = await controller.api.groupPayments(
          widget.group.id,
          page: _paymentPage + 1,
        );
        if (!mounted) return;
        setState(() {
          final ids = _payments.map((s) => s.id).toSet();
          _payments.addAll(rows.where((s) => ids.add(s.id)));
          _paymentPage++;
          _morePayments = rows.length == 200;
        });
      } else {
        final rows = await controller.api.history(
          groupId: widget.group.id,
          page: _historyPage + 1,
        );
        if (!mounted) return;
        setState(() {
          final ids = _history.map((h) => h['id']).toSet();
          _history.addAll(rows.where((h) => ids.add(h['id'])));
          _historyPage++;
          _moreHistory = rows.length == 100;
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
    final colors = BlistraColors.resolve(context);
    final detail = _detail, me = controller.me?.id;
    final owner = detail?.group.ownerId == me;
    final archived = detail?.group.archived ?? false;
    final names = {
      for (final m in detail?.members ?? <TripMember>[])
        m.user.id: m.user.displayName,
    };
    final group = detail?.group ?? widget.group;
    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: detail == null
          ? null
          : StickyActionBar(
              label: 'Add expense',
              onPressed: _busy || archived ? null : _expense,
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BlistraPageHeader(
              eyebrow: archived ? 'Trip · archived' : 'Trip · ${group.currency}',
              title: group.name,
              showAvatar: false,
              actions: [
                if (detail != null)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    enabled: !_busy,
                    onSelected: (action) {
                      if (action == 'export') {
                        _export();
                      } else {
                        _run(
                          () => controller.api.archiveGroup(
                            widget.group.id,
                            !archived,
                          ),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'export',
                        child: Text('Export ledger (JSON)'),
                      ),
                      if (owner)
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(archived ? 'Reopen trip' : 'Archive trip'),
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
            if (_busy)
              const PagePad(LinearProgressIndicator(minHeight: 2), top: 4),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                  children: [
                    if (_error != null)
                      PagePad(
                        EmptyCard(
                          message: _error!,
                          action: 'Retry',
                          onAction: _load,
                        ),
                        top: 4,
                      ),
                    if (detail == null && _error == null)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (detail != null) ...[
                      PagePad(
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (owner)
                              Pill(
                                'Invite member',
                                onTap: _busy || archived ? null : _invite,
                              ),
                            if (!owner)
                              Pill(
                                'Leave group',
                                color: colors.muted,
                                onTap: _busy ? null : _leave,
                              ),
                          ],
                        ),
                        top: 4,
                      ),
                      if (archived)
                        const PagePad(
                          StatusCard(
                            caption: 'Archived trip',
                            title: 'Ledger preserved',
                            subtitle:
                                'The ledger is preserved. Pending payments can still be confirmed or rejected. The owner can reopen this trip.',
                            leading: IconWell(Icons.inventory_2_outlined),
                          ),
                          top: 14,
                        ),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Group balances'),
                      const PagePad(
                        FinanceNote(
                          'Positive: owed to this person. Negative: this person owes the group. Currencies stay separate.',
                        ),
                      ),
                      PagePad(
                        GlassList(
                          children: [
                            if (detail.balances.isEmpty)
                              const GlassRow(
                                leading: IconWell(Icons.check_rounded),
                                title: 'All settled up',
                              ),
                            for (final b in detail.balances)
                              GlassRow(
                                title: names[b.userId] ?? 'Former member',
                                trailing: Text(
                                  b.amount.display(currencyCode: b.currency),
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: BlistraText.tabular,
                                    color: b.amount.isZero
                                        ? colors.muted
                                        : b.amount.isNegative
                                        ? oweTone(colors)
                                        : owedTone(colors),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Members'),
                      PagePad(
                        GlassList(
                          children: [
                            for (final m in detail.members)
                              GlassRow(
                                leading: UserAvatar(m.user),
                                title: m.user.displayName,
                                subtitle:
                                    '@${m.user.username} · ${m.owner ? 'Owner' : m.status.toLowerCase()}',
                                trailing:
                                    m.status != 'ACCEPTED' || m.user.id == me
                                    ? null
                                    : PopupMenuButton<String>(
                                        tooltip: 'Member actions',
                                        icon: Icon(
                                          Icons.more_horiz,
                                          color: colors.muted,
                                        ),
                                        onSelected: (action) async {
                                          if (action == 'pay') {
                                            await _payment(m.user);
                                          } else {
                                            await _run(
                                              () => controller.api
                                                  .transferGroup(
                                                    widget.group.id,
                                                    m.user.id,
                                                  ),
                                            );
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          if (!archived)
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
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Expenses'),
                      if (_expenses.isEmpty)
                        const PagePad(
                          EmptyCard(
                            message: 'Add the first expense for this trip.',
                          ),
                        )
                      else
                        PagePad(
                          GlassList(
                            children: [
                              for (final e in _expenses)
                                ExpenseTile(
                                  expense: e,
                                  meId: me,
                                  showDate: true,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ChangeNotifierProvider.value(
                                              value: controller,
                                              child: ExpenseDetailScreen(
                                                expense: e,
                                              ),
                                            ),
                                      ),
                                    );
                                    if (mounted) await _load();
                                  },
                                ),
                            ],
                          ),
                        ),
                      if (!_last)
                        Center(
                          child: TextButton(
                            onPressed: _busy ? null : _more,
                            child: const Text('Load more expenses'),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Payments'),
                      const PagePad(
                        FinanceNote(
                          'Recorded payments change balances only after the other participant confirms.',
                        ),
                      ),
                      if (_payments.isNotEmpty)
                        PagePad(
                          GlassList(
                            children: [
                              for (final s in _payments)
                                PaymentTile(
                                  settlement: s,
                                  busy: _busy,
                                  onDelete: s.editable
                                      ? () => _run(
                                          () => controller.deleteSettlement(s),
                                        )
                                      : null,
                                  onDecision: s.confirmable
                                      ? (yes) => _run(
                                          () => controller.decideSettlement(
                                            s.id,
                                            confirmed: yes,
                                          ),
                                        )
                                      : null,
                                ),
                            ],
                          ),
                        ),
                      if (_morePayments)
                        Center(
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _moreLedger(payments: true),
                            child: const Text('Load more payments'),
                          ),
                        ),
                      const SizedBox(height: 24),
                      const SectionHeader(title: 'Change history'),
                      PagePad(
                        FinanceHistoryList(
                          entries: _history,
                          meId: me,
                          names: names,
                        ),
                      ),
                      if (_moreHistory)
                        Center(
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => _moreLedger(payments: false),
                            child: const Text('Load more changes'),
                          ),
                        ),
                    ],
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

class FinanceHistoryList extends StatelessWidget {
  const FinanceHistoryList({
    super.key,
    required this.entries,
    this.meId,
    this.names = const {},
  });
  final List<Map<String, dynamic>> entries;
  final String? meId;
  final Map<String, String> names;

  Map<String, dynamic>? _state(dynamic value) {
    if (value == null) return null;
    try {
      return (value is String ? jsonDecode(value) : value)
          as Map<String, dynamic>;
    } on FormatException {
      return null;
    }
  }

  String _amountSummary(Map<String, dynamic> entry) {
    final before = entry['beforeAmount'];
    final after = entry['afterAmount'];
    final oldCurrency =
        _state(entry['beforeState'])?['currency'] ?? entry['currency'];
    final newCurrency =
        _state(entry['afterState'])?['currency'] ?? entry['currency'];
    return '${before == null ? '' : '$oldCurrency $before → '}'
        '${after == null ? 'removed' : '$newCurrency $after'}';
  }

  String _name(dynamic id) => id == meId
      ? 'You'
      : names[id] ??
            'Participant ${id.toString().substring(0, id.toString().length.clamp(0, 8))}';

  Widget _snapshot(
    BlistraColors colors,
    String label,
    Map<String, dynamic>? state,
  ) {
    final line = TextStyle(fontSize: 12, height: 1.45, color: colors.text);
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 2, 15, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BlistraText.caption(colors.muted)),
          const SizedBox(height: 3),
          if (state == null)
            Text('No record', style: line)
          else ...[
            Text('${state['currency']} ${state['amount']}', style: line),
            if (state['spentOn'] != null)
              Text('Date: ${state['spentOn']}', style: line),
            if (state['paidBy'] != null)
              Text('Paid by: ${_name(state['paidBy'])}', style: line),
            if (state['splitType'] != null)
              Text('Split: ${state['splitType']}', style: line),
            if (state['payerId'] != null)
              Text(
                '${_name(state['payerId'])} paid ${_name(state['payeeId'])}',
                style: line,
              ),
            if (state['status'] != null)
              Text('Status: ${state['status']}', style: line),
            for (final share in state['shares'] as List? ?? const [])
              Text(
                '${_name(share['userId'])}: ${state['currency']} ${share['amount']}',
                style: line,
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    if (entries.isEmpty) {
      return const EmptyCard(message: 'No changes recorded yet.');
    }
    return GlassList(
      children: [
        for (final h in entries)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 15),
              childrenPadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              iconColor: colors.muted,
              collapsedIconColor: colors.muted,
              title: Text(
                '${h['entityType']} · ${h['action']}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.text,
                ),
              ),
              subtitle: Text(
                '${h['actorId'] == meId ? 'You' : h['actorName'] ?? 'Participant'} · ${h['recordedAt']}\n'
                '${_amountSummary(h)}',
                style: TextStyle(fontSize: 11, color: colors.muted),
              ),
              children: [
                if (h['beforeState'] == null && h['afterState'] == null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 0, 15, 12),
                    child: Text(
                      'Split details were not recorded for this older change.',
                      style: TextStyle(fontSize: 12, color: colors.muted),
                    ),
                  )
                else ...[
                  _snapshot(colors, 'Before', _state(h['beforeState'])),
                  _snapshot(colors, 'After', _state(h['afterState'])),
                ],
              ],
            ),
          ),
      ],
    );
  }
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
