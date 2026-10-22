import 'dart:convert';

import 'package:flutter/foundation.dart';
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

/// Name claims read from a Google ID token, used only to pre-fill the
/// registration form (the backend verifies the token itself).
class GoogleNameClaims {
  const GoogleNameClaims({this.givenName, this.familyName, this.name});

  final String? givenName;
  final String? familyName;
  final String? name;

  static GoogleNameClaims fromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) return const GoogleNameClaims();
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
              as Map<String, dynamic>;
      String? read(String key) {
        final value = (payload[key] as String?)?.trim();
        return value == null || value.isEmpty ? null : value;
      }

      return GoogleNameClaims(
        givenName: read('given_name'),
        familyName: read('family_name'),
        name: read('name'),
      );
    } catch (_) {
      return const GoogleNameClaims();
    }
  }
}

/// Native Google Sign-In (Android Credential Manager).
///
/// The Web OAuth client id comes from
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=<id>.apps.googleusercontent.com`
/// or, when that is not set, from `android/app/google-services.json`
/// (`default_web_client_id`). It must also be listed in the backend's
/// `GOOGLE_CLIENT_IDS`. The APK's signing SHA-1 must be registered as an
/// Android OAuth client in the same Google Cloud project.
class GoogleSignInService implements GoogleIdTokenProvider {
  static const String serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  Future<void>? _initialized;

  @override
  Future<String?> getIdToken() async {
    final signIn = GoogleSignIn.instance;
    try {
      await (_initialized ??= signIn.initialize(
        serverClientId: serverClientId.isEmpty ? null : serverClientId,
      ));
      final account = await signIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleSignInUnavailable(
          "Google didn't return a sign-in token. Please try again.",
        );
      }
      return idToken;
    } on GoogleSignInException catch (error) {
      debugPrint('Google sign-in failed: ${error.code.name} ${error.description}');
      if (isUserCancellation(error)) return null;
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const GoogleSignInUnavailable(
          "Google couldn't verify this app. Please try again later.",
        );
      }
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
        _initialized = null;
        throw const GoogleSignInUnavailable(
          "Google sign-in isn't set up in this build.",
        );
      }
      throw GoogleSignInUnavailable(
        "Google sign-in couldn't start (${error.code.name}). Please try again.",
      );
    } finally {
      // Don't keep a Google session; the app has its own. Lets the user pick
      // a different account next time.
      try {
        await signIn.signOut();
      } catch (_) {}
    }
  }

  /// Credential Manager reports a misconfigured OAuth client (an APK signing
  /// SHA-1 not registered in Google Cloud: "[16] Account reauth failed") as a
  /// cancellation too. Only a real dismissal is silent.
  @visibleForTesting
  static bool isUserCancellation(GoogleSignInException error) {
    if (error.code != GoogleSignInExceptionCode.canceled) return false;
    final description = error.description?.toLowerCase();
    return description == null ||
        description.isEmpty ||
        description.contains('cancel');
  }
}
