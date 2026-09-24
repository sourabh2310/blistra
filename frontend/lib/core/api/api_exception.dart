/// Typed exceptions mapped from the backend error contract.
///
/// The backend returns errors of the shape
/// `{status, code, message, path, errors: [{field, message}]}`. Every
/// non-2xx response is turned into an [ApiException] with that payload, so
/// UI code can react to validation, authorization and server failures in a
/// type-safe way.
library;

class ApiException implements Exception {
  ApiException(this.statusCode, this.code, this.message,
      {this.fieldErrors = const {}, this.retryAfterSeconds});

  final int statusCode;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;

  /// Present on 429 resend-cooldown responses: seconds until retry.
  final int? retryAfterSeconds;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isValidationError => statusCode == 400;
  bool get isRateLimited => statusCode == 429;

  @override
  String toString() {
    if (fieldErrors.isEmpty) {
      return message.isEmpty ? 'Request failed (HTTP $statusCode)' : message;
    }
    final String details = fieldErrors.entries
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
    return '$message ($details)';
  }
}

/// Network transport failure (no connection, server unreachable, timeout).
class NetworkException extends ApiException {
  NetworkException(this.cause) : super(0, 'NETWORK_ERROR', cause.toString());

  final Object cause;
}