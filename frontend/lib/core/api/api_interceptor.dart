/// Request interception helpers: auth header injection.
///
/// Kept as pure functions so both [ApiClient] and legacy feature clients
/// attach the JWT identically without duplicating header logic.
library;

import 'dart:io';

Map<String, String> buildHeaders({String? token, bool json = true}) {
  final headers = <String, String>{
    if (json) HttpHeaders.contentTypeHeader: 'application/json',
    'Accept': 'application/json',
  };
  if (token != null && token.isNotEmpty) {
    headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
  }
  return headers;
}
