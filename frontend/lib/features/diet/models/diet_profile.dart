import 'dietary_preference.dart';

/// The authenticated user's diet preferences (backend `DietProfileResponse`).
class DietProfile {
  DietProfile({
    this.dietaryPreference,
    this.customPreference,
    this.dislikedFoods,
    this.notes,
  });

  factory DietProfile.fromJson(Map<String, dynamic> json) {
    return DietProfile(
      dietaryPreference:
          DietaryPreference.fromWire(json['dietaryPreference'] as String?),
      customPreference: json['customPreference'] as String?,
      dislikedFoods: json['dislikedFoods'] as String?,
      notes: json['notes'] as String?,
    );
  }

  /// Payload for `PUT /api/v1/diet/profile` (backend `DietProfileRequest`).
  Map<String, dynamic> toRequest() {
    return {
      'dietaryPreference': dietaryPreference?.wireName,
      'customPreference': customPreference,
      'dislikedFoods': dislikedFoods,
      'notes': notes,
    };
  }

  final DietaryPreference? dietaryPreference;
  final String? customPreference;
  final String? dislikedFoods;
  final String? notes;
}