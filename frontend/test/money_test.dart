import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/money/money.dart';

void main() {
  group('Money.parse', () {
    test('accepts integers without fraction', () {
      expect(Money.parse('42').toPlainString(), '42.0000');
    });

    test('pads short fractions to four digits', () {
      expect(Money.parse('1.23').toPlainString(), '1.2300');
      expect(Money.parse('0.0001').toPlainString(), '0.0001');
    });

    test('accepts the fixed maximum precision', () {
      expect(Money.parse('12345678901234.5678').toPlainString(),
          '12345678901234.5678');
    });

    test('rejects more than four fraction digits', () {
      expect(() => Money.parse('1.00001'), throwsFormatException);
    });

    test('rejects non-decimal input', () {
      expect(() => Money.parse('abc'), throwsFormatException);
      expect(() => Money.parse('1,000'), throwsFormatException);
      expect(() => Money.parse('-5'), throwsFormatException);
      expect(() => Money.parse('.5'), throwsFormatException);
    });
  });

  group('Money arithmetic', () {
    test('adds exactly without floating point drift', () {
      final Money sum = Money.parse('0.1') +
          Money.parse('0.2') +
          Money.parse('0.0001');
      expect(sum.toPlainString(), '0.3001');
    });

    test('subtracts and produces negatives', () {
      final Money diff = Money.zero() - Money.parse('5.5');
      expect(diff.toPlainString(), '-5.5000');
      expect(diff.isNegative, isTrue);
    });

    test('comparisons', () {
      expect(Money.parse('1.20') == Money.parse('1.2000'), isTrue);
      expect(Money.parse('1.21') > Money.parse('1.20'), isTrue);
      expect(Money.parse('0.01') < Money.parse('0.02'), isTrue);
      expect(Money.zero() <= Money.parse('0.0001'), isTrue);
    });
  });

  group('Money.format', () {
    test('groups thousands exactly', () {
      expect(Money.parse('1234567.89').format(), '1,234,567.8900');
    });

    test('keeps four fraction digits', () {
      expect(Money.parse('10.5').format(), '10.5000');
    });

    test('renders currency code prefix', () {
      expect(Money.parse('9.99').format(currencyCode: 'USD'), 'USD 9.9900');
    });

    test('renders negatives', () {
      expect((Money.zero() - Money.parse('1000')).format(), '-1,000.0000');
    });
  });

  test('hashing and equality follow exact value', () {
    final Money a = Money.parse('2.50');
    final Money b = Money.parse('2.5000');
    expect(a.hashCode, b.hashCode);
  });
}