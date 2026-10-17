/// Shared Finance building blocks: avatars, amount text, balance wording,
/// and the settle-up and budget sheets.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';
import '../finance_controller.dart';
import '../models.dart';

const Color owedColor = Color(0xFF22A861);
const Color oweColor = Color(0xFFE5484D);

/// Digits with at most two decimals.
final List<TextInputFormatter> amountFormatters = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
];

/// Normalizes user input ("12.", ".5") to a backend decimal string, or null.
String? normalizeAmount(String raw) {
  var text = raw.trim();
  if (text.isEmpty || text == '.') return null;
  if (text.startsWith('.')) text = '0$text';
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  final value = double.tryParse(text);
  if (value == null || value <= 0) return null;
  return text;
}

String friendlyError(Object error) {
  if (error is ApiException) return error.message;
  return 'Something went wrong. Please try again.';
}

String dayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (d.year == now.year) return DateFormat('EEE, d MMM').format(d);
  return DateFormat('d MMM yyyy').format(d);
}

/// "owes you ₹50" / "you owe ₹50" / "settled up" across currencies.
String balanceSentence(List<CurrencyAmount> balances, {String name = ''}) {
  final open = balances.where((b) => !b.amount.isZero).toList();
  if (open.isEmpty) return 'Settled up';
  final owed = open.where((b) => !b.amount.isNegative).map((b) => b.display).toList();
  final owe = open.where((b) => b.amount.isNegative).map((b) => b.amount.abs().display(currencyCode: b.currency)).toList();
  final parts = <String>[
    if (owed.isNotEmpty) '${name.isEmpty ? 'Owes you' : '$name owes you'} ${owed.join(' + ')}',
    if (owe.isNotEmpty) 'You owe ${owe.join(' + ')}',
  ];
  return parts.join(' · ');
}

Color balanceColor(List<CurrencyAmount> balances, BlistraColors colors) {
  final open = balances.where((b) => !b.amount.isZero).toList();
  if (open.isEmpty) return colors.muted;
  return open.every((b) => b.amount.isNegative) ? oweColor : owedColor;
}

class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar(this.category, {super.key, this.size = 42});

  final ExpenseCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: category.color.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(category.icon, color: category.color, size: size * .5),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar(this.user, {super.key, this.size = 40});

  final UserSummary user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final hue = (user.id.hashCode % 360).abs().toDouble();
    final tint = HSLColor.fromAHSL(1, hue, .55, colors.isDark ? .6 : .45).toColor();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: tint.withValues(alpha: .18),
      child: Text(
        user.initials,
        style: TextStyle(color: tint, fontWeight: FontWeight.w700, fontSize: size * .36),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: colors.muted,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// One line in an expense list: category, description, who paid, your effect.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({super.key, required this.expense, required this.meId, this.onTap});

  final Expense expense;
  final String? meId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final paidByMe = expense.paidBy.id == meId;
    final String subtitle;
    if (!expense.isShared) {
      subtitle = expense.category.label;
    } else if (paidByMe) {
      subtitle = 'You paid ${expense.amount.display(currencyCode: expense.currency)}';
    } else {
      subtitle = '${expense.paidBy.displayName} paid ${expense.amount.display(currencyCode: expense.currency)}';
    }
    Widget trailing;
    if (!expense.isShared) {
      trailing = Text(
        expense.amount.display(currencyCode: expense.currency),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: colors.text),
      );
    } else {
      final lent = !expense.myBalance.isNegative;
      final none = expense.myBalance.isZero;
      trailing = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            none ? 'not involved' : (lent ? 'you lent' : 'you borrowed'),
            style: TextStyle(fontSize: 11, color: none ? colors.muted : (lent ? owedColor : oweColor)),
          ),
          if (!none)
            Text(
              expense.myBalance.abs().display(currencyCode: expense.currency),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: lent ? owedColor : oweColor,
              ),
            ),
        ],
      );
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            CategoryAvatar(expense.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expense.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: colors.text),
                        ),
                      ),
                      if (expense.isShared) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.people_alt_rounded, size: 14, color: colors.muted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: colors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to record a repayment with one person.
Future<bool?> showSettleUpSheet(BuildContext context, {required Friend friend}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<FinanceController>(),
      child: _SettleUpSheet(friend: friend),
    ),
  );
}

class _SettleUpSheet extends StatefulWidget {
  const _SettleUpSheet({required this.friend});

  final Friend friend;

  @override
  State<_SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends State<_SettleUpSheet> {
  late final TextEditingController _amount;
  final TextEditingController _note = TextEditingController();
  late String _currency;
  late bool _iPaid;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final open = widget.friend.balances.where((b) => !b.amount.isZero).toList();
    final first = open.isEmpty ? null : open.first;
    _currency = first?.currency ?? context.read<FinanceController>().currency;
    // Default to the direction that clears the balance.
    _iPaid = first?.amount.isNegative ?? true;
    _amount = TextEditingController(
      text: first == null ? '' : first.amount.abs().display().replaceAll(',', ''),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _pickCurrency(String currency) {
    setState(() {
      _currency = currency;
      for (final b in widget.friend.balances) {
        if (b.currency == currency && !b.amount.isZero) {
          _iPaid = b.amount.isNegative;
          _amount.text = b.amount.abs().display().replaceAll(',', '');
        }
      }
    });
  }

  Future<void> _save() async {
    final amount = normalizeAmount(_amount.text);
    if (amount == null) {
      setState(() => _error = 'Enter an amount');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<FinanceController>().settleUp(
            friendId: widget.friend.user.id,
            iPaid: _iPaid,
            amount: amount,
            currency: _currency,
            note: _note.text,
          );
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
    final name = widget.friend.user.displayName;
    final currencies = {
      ...widget.friend.balances.where((b) => !b.amount.isZero).map((b) => b.currency),
      _currency,
    }.toList();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Settle up with $name',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.text)),
          const SizedBox(height: 6),
          Text(balanceSentence(widget.friend.balances, name: name),
              style: TextStyle(color: balanceColor(widget.friend.balances, colors))),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              const ButtonSegment(value: true, label: Text('I paid them'), icon: Icon(Icons.north_east_rounded)),
              ButtonSegment(value: false, label: Text('$name paid me', overflow: TextOverflow.ellipsis),
                  icon: const Icon(Icons.south_west_rounded)),
            ],
            selected: {_iPaid},
            onSelectionChanged: (s) => setState(() => _iPaid = s.first),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (currencies.length > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: DropdownButton<String>(
                    value: _currency,
                    items: [for (final c in currencies) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (c) => c == null ? null : _pickCurrency(c),
                  ),
                ),
              Expanded(
                child: TextField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: amountFormatters,
                  decoration: InputDecoration(labelText: 'Amount', prefixText: '$_currency '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _note,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Note (optional)', counterText: ''),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: oweColor)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded),
            label: const Text('Record payment'),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to set (or remove) a monthly budget.
Future<void> showBudgetSheet(BuildContext context, {Budget? existing, ExpenseCategory? category}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<FinanceController>(),
      child: _BudgetSheet(existing: existing, category: existing?.category ?? category),
    ),
  );
}

class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({this.existing, this.category});

  final Budget? existing;
  final ExpenseCategory? category;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final TextEditingController _limit;
  ExpenseCategory? _category;
  late String _currency;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
    _currency = widget.existing?.currency ?? context.read<FinanceController>().currency;
    _limit = TextEditingController(
      text: widget.existing == null ? '' : widget.existing!.limit.display().replaceAll(',', ''),
    );
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) Navigator.of(context).pop();
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
    final controller = context.read<FinanceController>();
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.existing == null ? 'Set a monthly budget' : 'Edit budget',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: colors.text)),
          const SizedBox(height: 14),
          DropdownButtonFormField<ExpenseCategory?>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Applies to'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All spending')),
              for (final c in ExpenseCategory.values) DropdownMenuItem(value: c, child: Text(c.label)),
            ],
            onChanged: widget.existing != null ? null : (c) => setState(() => _category = c),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _limit,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: amountFormatters,
            decoration: InputDecoration(labelText: 'Monthly limit', prefixText: '$_currency '),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: oweColor)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving
                ? null
                : () {
                    final limit = normalizeAmount(_limit.text);
                    if (limit == null) {
                      setState(() => _error = 'Enter a limit above zero');
                      return;
                    }
                    _run(() => controller.saveBudget(category: _category, currency: _currency, limit: limit));
                  },
            child: const Text('Save budget'),
          ),
          if (widget.existing != null)
            TextButton(
              onPressed: _saving ? null : () => _run(() => controller.deleteBudget(widget.existing!)),
              child: const Text('Remove budget', style: TextStyle(color: oweColor)),
            ),
        ],
      ),
    );
  }
}

/// Thin horizontal progress bar used for budgets and categories.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: 7,
        color: color,
        backgroundColor: color.withValues(alpha: .14),
      ),
    );
  }
}

Money sumMoney(Iterable<Money> values) => values.fold(Money.zero(), (a, b) => a + b);
