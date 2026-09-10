/// A failed request that reached the backend but did not succeed.
///
/// [status] is the HTTP status code, [code] the backend error code
/// (for example `VALIDATION_ERROR`, `INVALID_CREDENTIALS`,
/// `AUTHENTICATION_REQUIRED`, `RESOURCE_NOT_FOUND`) and [message] a
/// human-readable summary. [fieldErrors] maps request fields to messages when
/// the backend reported per-field validation failures.
class ApiException implements Exception {
  ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.fieldErrors = const {},
  });

  final int status;
  final String code;
  final String message;
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => status == 401;

  bool get isValidationFailure => status == 400;

  @override
  String toString() => 'ApiException($status $code: $message)';
}

/// The backend could not be reached (network or transport failure).
class NetworkException implements Exception {
  NetworkException([this.cause]);

  final Object? cause;

  @override
  String toString() =>
      'NetworkException(${cause == null ? 'unable to reach server' : cause})';
}

/// The response body could not be parsed as the expected JSON shape.
class ApiParseException implements Exception {
  ApiParseException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'ApiParseException: $message';
}