/// Shared form-field helpers for finance forms.
///
/// Amount values are validated as plain decimal strings so they can be sent
/// to the backend exactly (NUMERIC(19,4)); no floating point is used.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/money/money.dart';

final class FormValidators {
  FormValidators._();

  static final RegExp _decimal = RegExp(r'^\d+(\.\d+)?$');
  static final RegExp _currency = RegExp(r'^[A-Z]{3}$');

  static String? amount(String? value, {bool allowZero = false}) {
    final String v = value?.trim() ?? '';
    if (v.isEmpty) {
      return 'Amount is required';
    }
    if (!_decimal.hasMatch(v)) {
      return 'Enter a non-negative decimal number';
    }
    final int dot = v.indexOf('.');
    if (dot != -1 && v.length - dot - 1 > 4) {
      return 'At most 4 decimal places';
    }
    try {
      final Money money = Money.parse(v);
      if (!allowZero && money <= Money.zero()) {
        return 'Amount must be greater than zero';
      }
    } on FormatException {
      return 'Enter a valid decimal number';
    }
    return null;
  }

  static String? currency(String? value) {
    final String v = (value ?? '').trim().toUpperCase();
    if (v.isEmpty) {
      return 'Currency is required';
    }
    if (!_currency.hasMatch(v)) {
      return 'Three-letter currency code like USD';
    }
    return null;
  }

  static String? required(String? value, {String label = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String longest(List<String? Function()> checks) {
    for (final String? Function() check in checks) {
      final String? message = check();
      if (message != null) {
        return message;
      }
    }
    return '';
  }
}

/// Tappable date field that opens a month/day picker and formats its value
/// as ISO `yyyy-MM-dd`.
class AppDateField extends StatelessWidget {
  const AppDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.toDate,
  });

  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? toDate;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      child: InkWell(
        onTap: () async {
          final DateTime? picked = await showDatePicker(
            context: context,
            initialDate: value,
            firstDate: DateTime(2000),
            lastDate: toDate ?? DateTime(2100),
          );
          if (picked != null) {
            onChanged(picked);
          }
        },
        child: Text(
          DateFormat('yyyy-MM-dd').format(value),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// A [TextFormField] for currency codes that uppercases input.
class CurrencyField extends StatelessWidget {
  const CurrencyField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      maxLength: 3,
      decoration: const InputDecoration(
        labelText: 'Currency',
        hintText: 'USD',
        counterText: '',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.currency_exchange_outlined),
      ),
      validator: FormValidators.currency,
      onChanged: (String value) {
        final int selectionBefore = controller.selection.baseOffset;
        controller.value = TextEditingValue(
          text: value.toUpperCase(),
          selection: TextSelection.collapsed(
            offset: selectionBefore.clamp(0, value.length),
          ),
        );
      },
    );
  }
}

/// A [TextFormField] for monetary amounts.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    this.allowZero = false,
    this.label = 'Amount',
  });

  final TextEditingController controller;
  final bool allowZero;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.payments_outlined),
      ),
      validator: (String? value) => FormValidators.amount(value, allowZero: allowZero),
    );
  }
}