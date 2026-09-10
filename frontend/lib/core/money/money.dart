/// Exact monetary amount backed by a [BigInt] of 10^-4 currency units.
///
/// Floating point is never used for money. Parsing, arithmetic and
/// comparison operate on integer units, so values like `0.0001` survive
/// exactly and aggregations never accumulate floating-point drift.
///
/// This matches the backend representation: all money is stored as
/// NUMERIC(19,4) and travels over the wire as a decimal string.
library;

import 'dart:math' as math;

class Money {
  Money._(this._units);

  /// Value expressed in 10^-4 units of the currency.
  final BigInt _units;

  static const int scale = 4;

  static final BigInt _perUnit = BigInt.from(math.pow(10, scale));

  static final RegExp _decimalPattern = RegExp(r'^\d+(\.\d+)?$');

  static Money zero() => Money._(BigInt.zero);

  /// Parses a non-negative decimal string (for example `"42.5000"`) into
  /// exact units. Rejects values with more than [scale] fraction digits.
  factory Money.parse(String raw) {
    if (!_decimalPattern.hasMatch(raw)) {
      throw FormatException('Invalid monetary amount: $raw');
    }
    final int dot = raw.indexOf('.');
    if (dot == -1) {
      return Money._(BigInt.parse(raw) * _perUnit);
    }
    final String intPart = raw.substring(0, dot);
    final String fracPart = raw.substring(dot + 1);
    if (fracPart.length > scale) {
      throw FormatException(
        'More than $scale fractional digits in monetary amount: $raw',
      );
    }
    final BigInt intUnits = BigInt.parse(intPart) * _perUnit;
    final BigInt fracUnits = BigInt.parse(fracPart.padRight(scale, '0'));
    return Money._(intUnits + fracUnits);
  }

  Money operator +(Money other) => Money._(_units + other._units);

  Money operator -(Money other) => Money._(_units - other._units);

  bool operator >(Money other) => _units > other._units;

  bool operator <(Money other) => _units < other._units;

  bool operator >=(Money other) => _units >= other._units;

  bool operator <=(Money other) => _units <= other._units;

  bool get isNegative => _units.isNegative;

  bool get isZero => _units == BigInt.zero;

  @override
  bool operator ==(Object other) =>
      other is Money && other._units == _units;

  @override
  int get hashCode => _units.hashCode;

  /// Renders the exact plain decimal string at the fixed scale
  /// (for example `"42.5000"`).
  String toPlainString() {
    final bool negative = _units.isNegative;
    final BigInt abs = _units.abs();
    final BigInt intUnits = abs ~/ _perUnit;
    final String fracUnits = (abs % _perUnit).toString().padLeft(scale, '0');
    final String sign = negative ? '-' : '';
    return '$sign$intUnits.$fracUnits';
  }

  /// Renders with thousands separators and an optional currency code
  /// (for example `"USD 1,234,567.8900"`). Grouping is computed from the
  /// exact string representation; no floating point is involved.
  String format({String currencyCode = ''}) {
    final String plain = toPlainString();
    final bool negative = plain.startsWith('-');
    final String unsigned = negative ? plain.substring(1) : plain;
    final int dot = unsigned.indexOf('.');
    final String intPart = unsigned.substring(0, dot);
    final String fracPart = unsigned.substring(dot + 1);

    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intPart[i]);
    }
    final String rendered = '${negative ? '-' : ''}$buffer.$fracPart';
    return currencyCode.isEmpty ? rendered : '$currencyCode $rendered';
  }

  @override
  String toString() => toPlainString();
}