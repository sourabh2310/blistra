import 'wire.dart';

/// Supported water units. Only `ml`/`L` (and lowercase `mL`/`l`) contribute to
/// the day's total; descriptors like `glass`/`cup` are still recorded but do
/// not convert to millilitres (backend contract).
enum WaterUnit {
  ml('ml', 1),
  mL('mL', 1),
  L('L', 1000),
  l('l', 1000),
  glass('glass', 0),
  glasses('glasses', 0),
  cup('cup', 0),
  cups('cups', 0);

  const WaterUnit(this.wireName, this.millilitersPerUnit);

  final String wireName;
  final double millilitersPerUnit;

  String get label {
    return switch (this) {
      WaterUnit.ml || WaterUnit.mL => 'ml',
      WaterUnit.L || WaterUnit.l => 'litres',
      WaterUnit.glass || WaterUnit.glasses => 'glasses',
      WaterUnit.cup || WaterUnit.cups => 'cups',
    };
  }

  static WaterUnit fromWire(String? value) {
    if (value == null) return WaterUnit.ml;
    final v = value.trim();
    // Backend canonical: ML / L / GLASS / CUP (uppercase). Accept legacy
    // lowercase variants too.
    for (final unit in WaterUnit.values) {
      if (unit.wireName == v) return unit;
    }
    switch (v.toUpperCase()) {
      case 'ML':
      case 'MILLILITER':
      case 'MILLILITERS':
      case 'MILLILITRE':
      case 'MILLILITRES':
        return WaterUnit.ml;
      case 'L':
      case 'LITER':
      case 'LITERS':
      case 'LITRE':
      case 'LITRES':
        return WaterUnit.L;
      case 'GLASS':
      case 'GLASSES':
        return WaterUnit.glass;
      case 'CUP':
      case 'CUPS':
        return WaterUnit.cup;
    }
    return WaterUnit.ml;
  }
}

/// A single water-intake record (backend `WaterResponse`).
class WaterRecord {
  WaterRecord({
    required this.id,
    required this.amount,
    required this.unit,
    required this.consumedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory WaterRecord.fromJson(Map<String, dynamic> json) {
    return WaterRecord(
      id: json['id'] as String? ?? '',
      amount: toDouble(json['amount']) ?? 0,
      unit: WaterUnit.fromWire(json['unit'] as String?),
      consumedAt: DateTime.parse(json['consumedAt'] as String? ?? '')
          .toLocal(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
    );
  }

  /// Purely local helper: millilitres contributed to the daily total.
  double get milliliters {
    final perUnit = unit.millilitersPerUnit;
    if (perUnit == 0) {
      return 0;
    }
    return amount * perUnit;
  }

  final String id;
  final double amount;
  final WaterUnit unit;
  final DateTime consumedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}