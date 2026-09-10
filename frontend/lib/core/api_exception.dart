/// A structured API error surfaced from the backend's ApiErrorResponse contract
/// (status, code, message) or from transport/network failures.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isUnauthorized => statusCode == 401;

  bool get isConflict => statusCode == 409;

  bool get isNotFound => statusCode == 404;

  @override
  String toString() =>
      'ApiException(code: $code, status: $statusCode): $message';
}