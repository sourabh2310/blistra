/// Simple mutable holder for the current JWT, shared between [AuthController]
/// (which writes it) and [ApiClient] (which reads it for the Authorization
/// header). This avoids a circular dependency between the two.
class AuthToken {
  String? value;
}