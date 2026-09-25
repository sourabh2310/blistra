/// Dietary preference categories (backend `DietaryPreference`).
enum DietaryPreference {
  vegetarian('VEGETARIAN'),
  vegan('VEGAN'),
  nonVegetarian('NON_VEGETARIAN'),
  pescatarian('PESCATARIAN'),
  other('OTHER');

  const DietaryPreference(this.wireName);

  /// The exact value sent to / received from the backend.
  final String wireName;

  String get label {
    return switch (this) {
      DietaryPreference.vegetarian => 'Vegetarian',
      DietaryPreference.vegan => 'Vegan',
      DietaryPreference.nonVegetarian => 'Non-vegetarian',
      DietaryPreference.pescatarian => 'Pescatarian',
      DietaryPreference.other => 'Other',
    };
  }

  static DietaryPreference fromWire(String? value) {
    return DietaryPreference.values.firstWhere(
      (preference) => preference.wireName == value,
      orElse: () => DietaryPreference.other,
    );
  }
}