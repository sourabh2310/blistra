/// Client-side validation mirroring the backend contract. These guards exist
/// to give immediate feedback; the backend remains the source of truth.
class Validators {
  Validators._();

  static String? email(String? value) {
    final text = _trimmed(value);
    if (text.isEmpty) {
      return 'Email is required';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  static String? required(String? value) {
    if (_trimmed(value).isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  static String? mealTitle(String? value) {
    if (_trimmed(value).isEmpty) {
      return 'Meal title is required';
    }
    if ((value?.length ?? 0) > 200) {
      return 'Meal title cannot exceed 200 characters';
    }
    return null;
  }

  static String? notes(String? value, {int max = 2000}) {
    if ((value?.length ?? 0) > max) {
      return 'Cannot exceed $max characters';
    }
    return null;
  }

  static String? itemName(String? value) {
    if (_trimmed(value).isEmpty) {
      return 'Food name is required';
    }
    if ((value?.length ?? 0) > 200) {
      return 'Food name cannot exceed 200 characters';
    }
    return null;
  }

  static String? unit(String? value) {
    if ((value?.length ?? 0) > 50) {
      return 'Unit cannot exceed 50 characters';
    }
    return null;
  }

  /// Quantity must be a positive decimal.
  static String? positiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'Enter a valid number';
    }
    if (parsed <= 0) {
      return 'Must be greater than 0';
    }
    return null;
  }

  /// Nutrition values must be zero or greater.
  static String? nonNegativeNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final parsed = double.tryParse(value);
    if (parsed == null) {
      return 'Enter a valid number';
    }
    if (parsed < 0) {
      return 'Cannot be negative';
    }
    return null;
  }

  static String? waterAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Amount is required';
    }
    return positiveNumber(value);
  }

  static String? _trimmed(String? value) => value?.trim() ?? '';

  /// Parses a non-empty numeric input to a double, or returns null for blank.
  static double? parseOptionalNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return double.tryParse(value.trim());
  }
}