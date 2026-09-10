import 'package:intl/intl.dart';

class Refill {
  const Refill({
    required this.id,
    required this.medicineId,
    required this.refillDate,
    required this.quantity,
    this.remainingQuantity,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String medicineId;
  final DateTime refillDate;
  final double quantity;
  final double? remainingQuantity;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Refill.fromJson(Map<String, dynamic> json) => Refill(
        id: json['id'] as String,
        medicineId: json['medicineId'] as String,
        refillDate: DateTime.parse(json['refillDate'] as String),
        quantity: (json['quantity'] as num).toDouble(),
        remainingQuantity: (json['remainingQuantity'] as num?)?.toDouble(),
        notes: json['notes'] as String?,
        createdAt: _dateTimeFrom(json['createdAt']),
        updatedAt: _dateTimeFrom(json['updatedAt']),
      );

  String get quantityLabel => _fmt(quantity);

  String get remainingLabel =>
      remainingQuantity != null ? _fmt(remainingQuantity!) : '—';

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  static DateTime? _dateTimeFrom(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return null;
    }
    return DateTime.tryParse(raw)?.toLocal();
  }
}

String refillDateLabel(DateTime d) => DateFormat('dd MMM yyyy').format(d);