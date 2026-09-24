/// Pure registration/login field validators.
///
/// Shared by [AuthScreen] and unit-tested in
/// `test/registration_onboarding_test.dart`. No widgets, no I/O.
library;

/// Returns an error message, or null when [value] is a usable email.
/// Mirrors the backend shape (local@domain.tld); the server re-validates.
String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Email is required';
  }
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim())) {
    return 'Enter a valid email';
  }
  return null;
}

/// Returns an error message, or null when [value] is a usable password.
/// Registration/reset require 8+ characters with a letter and a digit
/// (mirrors the backend); sign-in accepts any non-empty password.
String? validatePassword(String? value, {required bool registering}) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (registering) {
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(value) ||
        !RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password needs a letter and a digit';
    }
  }
  return null;
}

/// Returns an error message, or null when [value] confirms [password].
String? validatePasswordConfirmation(String? value, String password) {
  if (value == null || value.isEmpty) {
    return 'Please confirm your password';
  }
  if (value != password) {
    return 'Passwords do not match';
  }
  return null;
}

/// Username: 3-30 chars, letters/digits/underscore/dot (backend-normalized).
String? validateUsername(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Username is required';
  }
  if (!RegExp(r'^[A-Za-z0-9_.]{3,30}$').hasMatch(value.trim())) {
    return 'Use 3-30 letters, digits, _ or .';
  }
  return null;
}

/// Canonical E.164 phone: leading + with country code (no regional guessing).
String? validatePhone(String? value, {bool required = true}) {
  final text = value == null ? '' : value.trim().replaceAll(RegExp(r'[\s\-().]'), '');
  if (text.isEmpty) {
    return required ? 'Phone number is required' : null;
  }
  if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(text)) {
    return 'Enter phone with country code, e.g. +919876543210';
  }
  return null;
}

/// Single login identifier: non-empty; must look like a username, email or
/// international phone number.
String? validateIdentifier(String? value) {
  final text = value == null ? '' : value.trim();
  if (text.isEmpty) {
    return 'Enter your username, email or phone';
  }
  if (text.contains('@')) {
    return validateEmail(text);
  }
  if (RegExp(r'^\+?[0-9][0-9\s\-()]{5,18}$').hasMatch(text)) {
    final digits = text.replaceAll(RegExp(r'[\s\-().]'), '');
    if (!RegExp(r'^\+[1-9][0-9]{6,14}$').hasMatch(digits)) {
      return 'Enter phone with country code, e.g. +919876543210';
    }
    return null;
  }
  return validateUsername(text);
}

/// 6-digit OTP code.
String? validateOtpCode(String? value) {
  if (value == null || !RegExp(r'^[0-9]{6}$').hasMatch(value.trim())) {
    return 'Enter the 6-digit code';
  }
  return null;
}

/// Display name: required, at most 120 chars.
String? validateDisplayName(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Display name is required';
  }
  if (value.trim().length > 120) {
    return 'Display name is too long';
  }
  return null;
}

/// ISO-3166 alpha-2 country code.
String? validateCountry(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Country is required';
  }
  if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(value.trim())) {
    return 'Use the 2-letter country code, e.g. IN';
  }
  return null;
}
