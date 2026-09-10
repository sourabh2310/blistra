/// Eating-event categories used to organise meals (backend `MealType`).
enum MealType {
  breakfast('BREAKFAST'),
  lunch('LUNCH'),
  dinner('DINNER'),
  snack('SNACK'),
  other('OTHER');

  const MealType(this.wireName);

  /// The exact value sent to / received from the backend.
  final String wireName;

  String get label {
    return switch (this) {
      MealType.breakfast => 'Breakfast',
      MealType.lunch => 'Lunch',
      MealType.dinner => 'Dinner',
      MealType.snack => 'Snack',
      MealType.other => 'Other',
    };
  }

  static MealType fromWire(String? value) {
    return MealType.values.firstWhere(
      (type) => type.wireName == value,
      orElse: () => MealType.other,
    );
  }
}