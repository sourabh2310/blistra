import 'package:google_sign_in/google_sign_in.dart';

/// Thrown when Google sign-in cannot run (missing configuration or a failure
/// reported by the platform). [message] is safe to show to the user.
class GoogleSignInUnavailable implements Exception {
  const GoogleSignInUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Source of a Google ID token for the backend to verify.
abstract class GoogleIdTokenProvider {
  /// Shows the Google account picker. Returns the ID token, or null if the
  /// user dismissed the picker.
  Future<String?> getIdToken();
}

/// Shared provider used by the login screen and sensitive-action re-auth.
/// Tests replace it.
GoogleIdTokenProvider googleIdTokenProvider = GoogleSignInService();

/// Native Google Sign-In. The Web OAuth client id is passed at build time:
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=<id>.apps.googleusercontent.com`
/// and must also be listed in the backend's `GOOGLE_CLIENT_IDS`.
class GoogleSignInService implements GoogleIdTokenProvider {
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  Future<void>? _initialized;

  @override
  Future<String?> getIdToken() async {
    if (serverClientId.isEmpty) {
      throw const GoogleSignInUnavailable(
        "Google sign-in isn't set up in this build.",
      );
    }
    final signIn = GoogleSignIn.instance;
    try {
      await (_initialized ??= signIn.initialize(serverClientId: serverClientId));
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInUnavailable(
          "Google didn't return a sign-in token. Please try again.",
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      throw const GoogleSignInUnavailable(
        "Couldn't sign in with Google. Please try again.",
      );
    } finally {
      // Don't keep a Google session; the app has its own. Lets the user pick
      // a different account next time.
      try {
        await signIn.signOut();
      } catch (_) {}
    }
  }
}
