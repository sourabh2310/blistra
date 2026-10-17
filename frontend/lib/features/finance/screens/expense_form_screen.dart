/// Add or edit an expense: personal by default, optionally split with
/// friends (equally, by exact amounts, percentages or shares) and paid by
/// anyone in the split.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/page_header.dart';
import '../finance_api.dart';
import '../finance_controller.dart';
import '../models.dart';
import '../widgets/finance_widgets.dart';

class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    this.existing,
    this.withFriend,
    this.groupId,
    this.groupMembers,
    this.groupCurrency,
  });
  final String? groupId;
  final List<UserSummary>? groupMembers;
  final String? groupCurrency;

  /// Expense being edited, or null to add one.
  final Expense? existing;

  /// Pre-selects this friend in the split (from a friend's page).
  final UserSummary? withFriend;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _amount = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  ExpenseCategory _category = ExpenseCategory.food;
  DateTime _date = DateTime.now();
  late String _currency;

  bool _split = false;
  bool _includeMe = true;
  final List<UserSummary> _friends = [];
  String? _paidBy; // null = me
  SplitType _type = SplitType.equal;
  final Map<String, TextEditingController> _values = {};

  bool _saving = false;
  String? _error;

  FinanceController get _controller => context.read<FinanceController>();

  @override
  void initState() {
    super.initState();
    final controller = _controller;
    _currency = widget.groupCurrency ?? controller.currency;
    final e = widget.existing;
    if (e != null) {
      _amount.text = e.amount.display().replaceAll(',', '');
      _description.text = e.description;
      _notes.text = e.notes ?? '';
      _category = e.category;
      _date = e.spentOn;
      _currency = e.currency;
      if (e.isShared) {
        final meId = controller.me?.id;
        _split = true;
        _type = e.splitType;
        _paidBy = e.paidBy.id == meId ? null : e.paidBy.id;
        _includeMe = e.shares.any((s) => s.user.id == meId);
        for (final share in e.shares) {
          if (share.user.id != meId) _friends.add(share.user);
          _valueFor(share.user.id).text = switch (e.splitType) {
            SplitType.exact => share.amount.display().replaceAll(',', ''),
            SplitType.percent || SplitType.shares => share.value ?? '',
            _ => '',
          };
        }
        if (e.paidBy.id != meId && !_friends.contains(e.paidBy)) {
          _friends.add(e.paidBy);
        }
      }
    } else if (widget.groupMembers != null) {
      _friends.addAll(
        widget.groupMembers!.where((u) => u.id != controller.me?.id),
      );
      _split = _friends.isNotEmpty;
    } else if (widget.withFriend != null) {
      _split = true;
      _friends.add(widget.withFriend!);
    }
    if (controller.status == FinanceLoadStatus.idle) {
      controller.loadAll();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    _notes.dispose();
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _valueFor(String userId) =>
      _values.putIfAbsent(userId, () => TextEditingController());

  /// Everyone who shares the cost, in display order (me first).
  List<UserSummary> _participants(UserSummary? me) => [
    if (_includeMe && me != null) me,
    ..._friends,
  ];

  Money? get _amountMoney {
    final normalized = normalizeAmount(_amount.text);
    if (normalized == null) return null;
    try {
      return Money.parse(normalized);
    } on FormatException {
      return null;
    }
  }

  /// Client-side check mirroring the server so mistakes show instantly.
  String? _splitProblem(UserSummary? me) {
    if (!_split) return null;
    final people = _participants(me);
    if (_friends.isEmpty) return 'Pick at least one friend to split with';
    if (people.isEmpty) return 'Add someone to the split';
    if (_paidBy != null && !_includeMe) {
      return 'If a friend paid, include yourself in the split';
    }
    final total = _amountMoney;
    if (total == null) return null;
    switch (_type) {
      case SplitType.exact:
        final sum = sumMoney(
          people.map(
            (p) => Money.tryParse(normalizeAmount(_valueFor(p.id).text)),
          ),
        );
        if (sum != total) {
          final diff = total - sum;
          return diff.isNegative
              ? '${diff.abs().display(currencyCode: _currency)} over the total'
              : '${diff.display(currencyCode: _currency)} left to assign';
        }
      case SplitType.percent:
        final sum = people.fold<double>(
          0,
          (a, p) => a + (double.tryParse(_valueFor(p.id).text) ?? 0),
        );
        if ((sum - 100).abs() > 0.0001) {
          return 'Percentages add up to ${_trim(sum)}%, not 100%';
        }
      case SplitType.shares:
        final sum = people.fold<double>(
          0,
          (a, p) => a + (double.tryParse(_valueFor(p.id).text) ?? 0),
        );
        if (sum <= 0) return 'Give at least one person a share';
      default:
        break;
    }
    return null;
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Approximate per-person preview (display only; the server computes cents).
  String _preview(UserSummary person, UserSummary? me) {
    final total = _amountMoney;
    if (total == null) return '';
    final people = _participants(me);
    final t = total.toDouble();
    double share;
    switch (_type) {
      case SplitType.equal:
        share = t / people.length;
      case SplitType.percent:
        share = t * (double.tryParse(_valueFor(person.id).text) ?? 0) / 100;
      case SplitType.shares:
        final weights = people.fold<double>(
          0,
          (a, p) => a + (double.tryParse(_valueFor(p.id).text) ?? 0),
        );
        share = weights == 0
            ? 0
            : t * (double.tryParse(_valueFor(person.id).text) ?? 0) / weights;
      default:
        return '';
    }
    return NumberFormat.currency(
      name: _currency,
      symbol: _symbol,
      decimalDigits: 2,
    ).format(share);
  }

  String get _symbol =>
      Money.zero().display(currencyCode: _currency).replaceAll('0', '').trim();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickFriends(List<Friend> friends) async {
    final selected = await showModalBottomSheet<List<UserSummary>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FriendPicker(friends: friends, initial: _friends),
    );
    if (selected == null) return;
    setState(() {
      _friends
        ..clear()
        ..addAll(selected);
      if (_paidBy != null && !_friends.any((f) => f.id == _paidBy)) {
        _paidBy = null;
      }
    });
  }

  Future<void> _save() async {
    final me = _controller.me;
    final amount = normalizeAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    if (_description.text.trim().isEmpty) {
      setState(() => _error = 'Add a short description, e.g. "Dinner"');
      return;
    }
    final problem = _splitProblem(me);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    if (_split && me == null) {
      setState(
        () => _error = 'Still loading your friends. Try again in a moment.',
      );
      return;
    }
    final people = _split ? _participants(me) : <UserSummary>[];
    final draft = ExpenseDraft(
      groupId: widget.groupId ?? widget.existing?.groupId,
      description: _description.text,
      category: _category,
      amount: amount,
      currency: _currency,
      spentOn: _date,
      notes: _notes.text,
      paidBy: _split ? _paidBy : null,
      splitType: _split ? _type : SplitType.none,
      participants: [
        for (final p in people)
          (
            p.id,
            switch (_type) {
              SplitType.exact => normalizeAmount(_valueFor(p.id).text) ?? '0',
              SplitType.percent || SplitType.shares =>
                _valueFor(p.id).text.trim().isEmpty
                    ? '0'
                    : _valueFor(p.id).text.trim(),
              _ => null,
            },
          ),
      ],
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _controller.saveExpense(draft, id: widget.existing?.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final controller = context.watch<FinanceController>();
    final me = controller.me;
    final accepted = widget.groupMembers == null
        ? controller.friends.acceptedFriends
        : widget.groupMembers!
              .where((u) => u.id != controller.me?.id)
              .map((u) => Friend(user: u, isFriend: true, balances: const []))
              .toList();
    final problem = _splitProblem(me);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            BlistraPageHeader(
              title: widget.existing == null ? 'Add expense' : 'Edit expense',
              showAvatar: false,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            DropdownButton<String>(
                              value: _currency,
                              underline: const SizedBox.shrink(),
                              items: [
                                for (final c in {
                                  ...FinanceController.commonCurrencies,
                                  _currency,
                                })
                                  DropdownMenuItem(value: c, child: Text(c)),
                              ],
                              onChanged: (c) => c == null
                                  ? null
                                  : setState(() => _currency = c),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                key: const Key('expense-amount'),
                                controller: _amount,
                                autofocus: widget.existing == null,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: amountFormatters,
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w700,
                                  color: colors.text,
                                ),
                                decoration: const InputDecoration(
                                  hintText: '0',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        TextField(
                          key: const Key('expense-description'),
                          controller: _description,
                          textCapitalization: TextCapitalization.sentences,
                          maxLength: 255,
                          decoration: const InputDecoration(
                            labelText: 'What was it for?',
                            hintText: 'Dinner, cab, groceries…',
                            counterText: '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SectionLabel('Category'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in ExpenseCategory.values)
                        ChoiceChip(
                          avatar: Icon(c.icon, size: 18, color: c.color),
                          label: Text(c.label),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                    ],
                  ),
                  const SectionLabel('Date'),
                  GlassCard(
                    padding: EdgeInsets.zero,
                    onTap: _pickDate,
                    child: ListTile(
                      leading: const Icon(Icons.event_rounded),
                      title: Text(dayLabel(_date)),
                      subtitle: Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_date),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                  const SectionLabel('Split'),
                  GlassCard(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(widget.groupId == null ? 'Split with friends' : 'Split with group members'),
                          subtitle: Text(
                            _split
                                ? 'Shared cost'
                                : 'Personal expense — only you',
                          ),
                          value: _split,
                          onChanged: (v) => setState(() => _split = v),
                        ),
                        if (_split)
                          ..._splitSection(
                            context,
                            colors,
                            me,
                            accepted,
                            problem,
                          ),
                      ],
                    ),
                  ),
                  const SectionLabel('Notes'),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    minLines: 1,
                    maxLength: 1000,
                    decoration: const InputDecoration(
                      hintText: 'Optional',
                      counterText: '',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: oweColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    key: const Key('expense-save'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      widget.existing == null ? 'Save expense' : 'Save changes',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _splitSection(
    BuildContext context,
    BlistraColors colors,
    UserSummary? me,
    List<Friend> accepted,
    String? problem,
  ) {
    if (accepted.isEmpty && _friends.isEmpty) {
      return [
        Text(
          widget.groupId == null
              ? 'Add friends by username in the Friends tab to split costs with them.'
              : 'Invite a member and wait for them to join this group before splitting an expense.',
          style: TextStyle(color: colors.muted),
        ),
      ];
    }
    final people = _participants(me);
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final f in _friends)
            InputChip(
              avatar: UserAvatar(f, size: 24),
              label: Text(f.displayName),
              onDeleted: () => setState(() {
                _friends.remove(f);
                if (_paidBy == f.id) _paidBy = null;
              }),
            ),
          ActionChip(
            avatar: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: Text(_friends.isEmpty ? (widget.groupId == null ? 'Choose friends' : 'Choose members') : 'Edit'),
            onPressed: () => _pickFriends(accepted),
          ),
        ],
      ),
      const SizedBox(height: 4),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: _includeMe,
        onChanged: (v) => setState(() => _includeMe = v ?? true),
        title: const Text('Include me in the split'),
        subtitle: _includeMe
            ? null
            : const Text('You paid on their behalf; they owe it all'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      DropdownButtonFormField<String?>(
        key: ValueKey('paid-${_friends.length}'),
        initialValue: _paidBy,
        decoration: const InputDecoration(labelText: 'Paid by'),
        items: [
          const DropdownMenuItem(value: null, child: Text('You')),
          for (final f in _friends)
            DropdownMenuItem(value: f.id, child: Text(f.displayName)),
        ],
        onChanged: (v) => setState(() => _paidBy = v),
      ),
      const SizedBox(height: 12),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<SplitType>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: SplitType.equal, label: Text('Equal')),
            ButtonSegment(value: SplitType.exact, label: Text('Exact')),
            ButtonSegment(value: SplitType.percent, label: Text('%')),
            ButtonSegment(value: SplitType.shares, label: Text('Shares')),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() {
            _type = s.first;
            if (_type == SplitType.shares) {
              for (final p in people) {
                if (_valueFor(p.id).text.trim().isEmpty) {
                  _valueFor(p.id).text = '1';
                }
              }
            }
          }),
        ),
      ),
      const SizedBox(height: 8),
      for (final p in people)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              UserAvatar(p, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  p.id == me?.id ? 'You' : p.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (_type == SplitType.equal)
                Text(_preview(p, me), style: TextStyle(color: colors.muted))
              else ...[
                if (_type != SplitType.exact)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      _preview(p, me),
                      style: TextStyle(color: colors.muted, fontSize: 12),
                    ),
                  ),
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: _valueFor(p.id),
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: amountFormatters,
                    decoration: InputDecoration(
                      isDense: true,
                      prefixText: _type == SplitType.exact
                          ? '$_currency '
                          : null,
                      suffixText: switch (_type) {
                        SplitType.percent => '%',
                        SplitType.shares => '×',
                        _ => null,
                      },
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ],
          ),
        ),
      if (problem != null && _amountMoney != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            problem,
            style: const TextStyle(color: oweColor, fontSize: 12.5),
          ),
        ),
    ];
  }
}

class _FriendPicker extends StatefulWidget {
  const _FriendPicker({required this.friends, required this.initial});

  final List<Friend> friends;
  final List<UserSummary> initial;

  @override
  State<_FriendPicker> createState() => _FriendPickerState();
}

class _FriendPickerState extends State<_FriendPicker> {
  late final Set<String> _selected = widget.initial.map((u) => u.id).toSet();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final q = _query.toLowerCase();
    final visible = widget.friends
        .where(
          (f) =>
              q.isEmpty ||
              f.user.displayName.toLowerCase().contains(q) ||
              f.user.username.contains(q),
        )
        .toList();
    // Keep already-selected people (e.g. former friends on an old expense).
    final extra = widget.initial
        .where((u) => !widget.friends.any((f) => f.user.id == u.id))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search friends',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final u in [...extra, ...visible.map((f) => f.user)])
                  CheckboxListTile(
                    value: _selected.contains(u.id),
                    secondary: UserAvatar(u),
                    title: Text(u.displayName),
                    subtitle: Text(
                      '@${u.username}',
                      style: TextStyle(color: colors.muted),
                    ),
                    onChanged: (v) => setState(
                      () => v == true
                          ? _selected.add(u.id)
                          : _selected.remove(u.id),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () {
                final all = [...extra, ...widget.friends.map((f) => f.user)];
                Navigator.of(context)
                    .pop(all.where((u) => _selected.contains(u.id)).toList());
              },
              child: Text(
                _selected.isEmpty ? 'Done' : 'Split with ${_selected.length}',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
