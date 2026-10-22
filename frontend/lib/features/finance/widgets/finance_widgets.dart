/// Shared Finance building blocks: avatars, expense rows, balance wording,
/// amount fields, and the settle-up and budget sheets.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/blistra_ui.dart';
import '../finance_controller.dart';
import '../models.dart';

/// Colour for money coming back to you (owed to you, you lent).
Color owedTone(BlistraColors colors) => colors.accentText;

/// Colour for money you owe (you owe, you borrowed).
Color oweTone(BlistraColors colors) => colors.warning;

/// Digits with at most two decimals.
final List<TextInputFormatter> amountFormatters = [
  TextInputFormatter.withFunction((oldValue, newValue) =>
      RegExp(r'^\d*\.?\d{0,4}$').hasMatch(newValue.text) ? newValue : oldValue),
];

/// Normalizes user input ("12.", ".5") to a backend decimal string, or null.
String? normalizeAmount(String raw) {
  var text = raw.trim();
  if (text.isEmpty || text == '.') return null;
  if (text.startsWith('.')) text = '0$text';
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  try { if (Money.parse(text).isZero) return null; }
  on FormatException { return null; }
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
  final owed = open
      .where((b) => !b.amount.isNegative)
      .map((b) => b.display)
      .toList();
  final owe = open
      .where((b) => b.amount.isNegative)
      .map((b) => b.amount.abs().display(currencyCode: b.currency))
      .toList();
  final parts = <String>[
    if (owed.isNotEmpty)
      '${name.isEmpty ? 'Owes you' : '$name owes you'} ${owed.join(' + ')}',
    if (owe.isNotEmpty) 'You owe ${owe.join(' + ')}',
  ];
  return parts.join(' · ');
}

Color balanceColor(List<CurrencyAmount> balances, BlistraColors colors) {
  final open = balances.where((b) => !b.amount.isZero).toList();
  if (open.isEmpty) return colors.muted;
  return open.every((b) => b.amount.isNegative)
      ? oweTone(colors)
      : owedTone(colors);
}

/// Neutral icon well for an expense category.
class CategoryWell extends StatelessWidget {
  const CategoryWell(this.category, {super.key, this.size = 36});

  final ExpenseCategory category;
  final double size;

  @override
  Widget build(BuildContext context) => IconWell(category.icon, size: size);
}

class UserAvatar extends StatelessWidget {
  const UserAvatar(this.user, {super.key, this.size = 36});

  final UserSummary user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final tint = colors.data[user.id.hashCode.abs() % colors.data.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(
        user.initials,
        style: TextStyle(
          color: tint,
          fontWeight: FontWeight.w700,
          fontSize: size * .36,
        ),
      ),
    );
  }
}

/// Muted footnote under a section ("Currencies stay separate.").
class FinanceNote extends StatelessWidget {
  const FinanceNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 11.5, height: 1.4, color: colors.muted),
      ),
    );
  }
}

/// Inline error line for forms and sheets.
class FinanceError extends StatelessWidget {
  const FinanceError(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(
          color: colors.danger,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Glass amount input: currency prefix, decimal keyboard, amount filter.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.label,
    required this.controller,
    required this.currency,
    this.autofocus = false,
    this.large = false,
    this.onChanged,
    this.currencyPicker,
    this.inputKey,
  });

  final String label;
  final TextEditingController controller;

  /// Key for the inner [TextField], for tests.
  final Key? inputKey;
  final String currency;
  final bool autofocus;

  /// Big serif figure for the main amount of a form.
  final bool large;
  final ValueChanged<String>? onChanged;

  /// Replaces the plain currency prefix with a picker.
  final Widget? currencyPicker;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final style = large
        ? BlistraText.serif(30, colors.text)
        : TextStyle(fontSize: 14, color: colors.text);
    return FieldCard(
      label: label,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          currencyPicker ??
              Text(
                '$currency ',
                style: style.copyWith(color: colors.muted),
              ),
          if (currencyPicker != null) const SizedBox(width: 6),
          Expanded(
            child: TextField(
              key: inputKey,
              controller: controller,
              autofocus: autofocus,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amountFormatters,
              style: style,
              onChanged: onChanged,
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                hintText: '0',
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintStyle: style.copyWith(color: colors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact currency picker shown inside an [AmountField].
class CurrencyPicker extends StatelessWidget {
  const CurrencyPicker({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String value;
  final Iterable<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return PopupMenuButton<String>(
      tooltip: 'Currency',
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final c in options)
          CheckedPopupMenuItem(value: c, checked: c == value, child: Text(c)),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.accentSoft,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.accentText,
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 16, color: colors.accentText),
          ],
        ),
      ),
    );
  }
}

/// Your effect of an expense, right-aligned: the amount for personal
/// expenses, or what you lent or borrowed for shared ones.
class ExpenseAmount extends StatelessWidget {
  const ExpenseAmount({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    final amountStyle = TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 13.5,
      fontFeatures: BlistraText.tabular,
      color: colors.text,
    );
    if (!expense.isShared) {
      return Text(
        expense.amount.display(currencyCode: expense.currency),
        style: amountStyle,
      );
    }
    final lent = !expense.myBalance.isNegative;
    final none = expense.myBalance.isZero;
    final tone = none ? colors.muted : (lent ? owedTone(colors) : oweTone(colors));
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          none ? 'not involved' : (lent ? 'you lent' : 'you borrowed'),
          style: TextStyle(fontSize: 10.5, color: tone),
        ),
        if (!none)
          Text(
            expense.myBalance.abs().display(currencyCode: expense.currency),
            style: amountStyle.copyWith(color: tone),
          ),
      ],
    );
  }
}

/// One row of an expense list (inside a [GlassList]): category well,
/// description, who paid, and your effect on the right.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.meId,
    this.onTap,
    this.showDate = false,
  });

  final Expense expense;
  final String? meId;
  final VoidCallback? onTap;

  /// Appends the day ("Today", "Mon, 12 Oct") to the subtitle.
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final paidByMe = expense.paidBy.id == meId;
    final String who;
    if (!expense.isShared) {
      who = expense.category.label;
    } else if (paidByMe) {
      who =
          'You paid ${expense.amount.display(currencyCode: expense.currency)}';
    } else {
      who =
          '${expense.paidBy.displayName} paid ${expense.amount.display(currencyCode: expense.currency)}';
    }
    return GlassRow(
      leading: CategoryWell(expense.category),
      title: expense.description,
      subtitle: [
        if (expense.isShared) 'Shared',
        who,
        if (showDate) dayLabel(expense.spentOn),
      ].join(' · '),
      trailing: ExpenseAmount(expense: expense),
      onTap: onTap,
    );
  }
}

/// Grabber-less sheet body: serif title, optional subtitle, then content.
class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    this.subtitle,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = BlistraColors.resolve(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        kPageGutter,
        0,
        kPageGutter,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: BlistraText.serif(22, colors.text)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: colors.muted),
              ),
            ],
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to record a repayment with one person.
Future<bool?> showSettleUpSheet(
  BuildContext context, {
  required Friend friend,
  String? groupId,
  String? currency,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<FinanceController>(),
      child: _SettleUpSheet(
        friend: friend,
        groupId: groupId,
        currency: currency,
      ),
    ),
  );
}

class _SettleUpSheet extends StatefulWidget {
  const _SettleUpSheet({required this.friend, this.groupId, this.currency});

  final Friend friend;
  final String? groupId;
  final String? currency;

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
    _currency =
        widget.currency ??
        first?.currency ??
        context.read<FinanceController>().currency;
    // Default to the direction that clears the balance.
    _iPaid = first?.amount.isNegative ?? true;
    _amount = TextEditingController(
      text: first == null
          ? ''
          : first.amount.abs().display().replaceAll(',', ''),
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
        groupId: widget.groupId,
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
      ...FinanceController.commonCurrencies,
      ...widget.friend.balances
          .where((b) => !b.amount.isZero)
          .map((b) => b.currency),
      _currency,
    }.toList();
    return _SheetBody(
      title: 'Settle up with $name',
      subtitle:
          'The other participant must confirm. Your balance changes only after confirmation.',
      children: [
        Text(
          balanceSentence(widget.friend.balances, name: name),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: balanceColor(widget.friend.balances, colors),
          ),
        ),
        const SizedBox(height: 14),
        GlassSegmented<bool>(
          options: [(true, 'I paid them'), (false, '$name paid me')],
          selected: _iPaid,
          onChanged: (v) => setState(() => _iPaid = v),
        ),
        const SizedBox(height: 12),
        AmountField(
          label: 'Amount',
          controller: _amount,
          currency: _currency,
          autofocus: true,
          currencyPicker: currencies.length > 1
              ? CurrencyPicker(
                  value: _currency,
                  options: currencies,
                  onChanged: _pickCurrency,
                )
              : null,
        ),
        FieldCard(
          label: 'Note (optional)',
          child: TextField(
            controller: _note,
            maxLength: 255,
            style: TextStyle(fontSize: 14, color: colors.text),
            decoration: const InputDecoration(
              isDense: true,
              filled: false,
              counterText: '',
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
            ),
          ),
        ),
        if (_error != null) FinanceError(_error!),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.onAccent,
                  ),
                )
              : const Text('Record payment'),
        ),
      ],
    );
  }
}

/// Bottom sheet to set (or remove) a monthly budget.
Future<void> showBudgetSheet(
  BuildContext context, {
  Budget? existing,
  ExpenseCategory? category,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: context.read<FinanceController>(),
      child: _BudgetSheet(
        existing: existing,
        category: existing?.category ?? category,
      ),
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
    _currency =
        widget.existing?.currency ?? context.read<FinanceController>().currency;
    _limit = TextEditingController(
      text: widget.existing == null
          ? ''
          : widget.existing!.limit.display().replaceAll(',', ''),
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
    return _SheetBody(
      title: widget.existing == null ? 'Set a monthly budget' : 'Edit budget',
      children: [
        FieldCard(
          label: 'Applies to',
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ExpenseCategory?>(
              value: _category,
              isDense: true,
              isExpanded: true,
              style: TextStyle(fontSize: 14, color: colors.text),
              dropdownColor: colors.sheet,
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All spending'),
                ),
                for (final c in ExpenseCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: widget.existing != null
                  ? null
                  : (c) => setState(() => _category = c),
            ),
          ),
        ),
        AmountField(
          label: 'Monthly limit',
          controller: _limit,
          currency: _currency,
          autofocus: true,
        ),
        if (_error != null) FinanceError(_error!),
        const SizedBox(height: 6),
        FilledButton(
          onPressed: _saving
              ? null
              : () {
                  final limit = normalizeAmount(_limit.text);
                  if (limit == null) {
                    setState(() => _error = 'Enter a limit above zero');
                    return;
                  }
                  _run(
                    () => controller.saveBudget(
                      category: _category,
                      currency: _currency,
                      limit: limit,
                    ),
                  );
                },
          child: const Text('Save budget'),
        ),
        if (widget.existing != null)
          TextButton(
            onPressed: _saving
                ? null
                : () => _run(() => controller.deleteBudget(widget.existing!)),
            child: Text(
              'Remove budget',
              style: TextStyle(color: colors.danger),
            ),
          ),
      ],
    );
  }
}

Money sumMoney(Iterable<Money> values) =>
    values.fold(Money.zero(), (a, b) => a + b);

/// Formats a computed (non-negative) double as money in [currency].
String displayDouble(double value, String currency) =>
    Money.parse(value.toStringAsFixed(2)).display(currencyCode: currency);
