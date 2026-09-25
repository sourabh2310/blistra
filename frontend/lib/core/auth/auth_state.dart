/// In-memory authentication session backed by the real backend API.
///
/// V1 identity: one account reachable via username, email or phone, with
/// explicit email/phone verification flags and onboarding state. Every async
/// operation ends in a terminal state (no infinite spinners): failures set
/// [lastError] and restore a non-busy status.
///
/// Flow: register (PENDING_VERIFICATION + token) → verify email/phone →
/// profile/health setup → complete onboarding → Home. Login accepts any
/// identifier; the UI routes on [needsVerification]/[needsOnboarding].
///
/// No fake credentials. No passwords stored. No tokens or OTPs logged.
library;

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import 'auth_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, busy }

class AuthState extends ChangeNotifier {
  AuthState({required this.apiClient, AuthStorage? storage})
      : _storage = storage ?? AuthStorage();

  final ApiClient apiClient;
  final AuthStorage _storage;

  AuthStatus _status = AuthStatus.unknown;
  String _userEmail = '';
  UserAccountDto? _account;
  ApiException? _lastError;
  bool _justRegistered = false;

  /// True only for the session created by [register] until onboarding
  /// completes, logout, or restart. Lets [AuthGate] keep the fresh account in
  /// the onboarding wizard instead of dropping it on Home mid-flow.
  bool get justRegistered => _justRegistered;

  AuthStatus get status => _status;
  String get userEmail => _account?.email ?? _userEmail;
  String get username => _account?.username ?? '';
  String? get phone => _account?.phone;
  UserAccountDto? get account => _account;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  ApiException? get lastError => _lastError;

  bool get needsVerification =>
      isAuthenticated && (_account?.needsVerification ?? false);
  bool get needsOnboarding =>
      isAuthenticated && !(_account?.onboardingCompleted ?? true);

  /// Restores a persisted session at startup. Must be awaited before the
  /// first frame decides between shell and login.
  Future<void> restore() async {
    try {
      final token = await _storage.readToken();
      final email = await _storage.readEmail();
      if (token != null && token.isNotEmpty) {
        apiClient.token = token;
        _userEmail = email ?? '';
        _status = AuthStatus.authenticated;
        // Best-effort: hydrate flags so routing is correct without a restart.
        try {
          final profile = await apiClient.fetchProfile();
          _account = UserAccountDto(
            id: profile.userId,
            username: profile.username,
            email: profile.email,
            phone: profile.phone,
            emailVerified: profile.emailVerified,
            phoneVerified: profile.phoneVerified,
            onboardingCompleted: profile.onboardingCompleted,
            status: profile.status,
          );
          _userEmail = profile.email;
        } catch (_) {
          // Offline: keep the persisted session; flags load on next action.
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Called by [ApiClient.onUnauthorized] on HTTP 401.
  Future<void> handleUnauthorized() async {
    apiClient.token = null;
    await _storage.clear();
    _userEmail = '';
    _account = null;
    _lastError = ApiException(401, 'UNAUTHORIZED', 'Session expired.');
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Registers a full V1 account. Returns the account on success (already
  /// authenticated with a session token for the verification steps).
  Future<UserAccountDto?> register({
    required String username,
    required String email,
    String? phone,
    required String password,
    String? displayName,
    bool termsAccepted = true,
  }) async {
    _setBusy();
    try {
      final account = await apiClient.register(
        username: username,
        email: email,
        phone: phone?.isEmpty == true ? null : phone,
        password: password,
        displayName: displayName?.isEmpty == true ? null : displayName,
        termsAccepted: termsAccepted,
      );
      _account = account;
      _userEmail = account.email;
      await _storage.saveSession(
        token: apiClient.token ?? account.token ?? '',
        email: account.email,
      );
      _lastError = null;
      _status = AuthStatus.authenticated;
      _justRegistered = true;
      notifyListeners();
      return account;
    } on ApiException catch (error) {
      _fail(_safe(error));
      return null;
    } catch (error) {
      _fail(NetworkException(error));
      return null;
    }
  }

  /// Single-field login: username, email or phone + password.
  Future<UserAccountDto?> login({
    required String identifier,
    required String password,
  }) async {
    _setBusy();
    try {
      final AuthResponseDto response = await apiClient.login(
        identifier: identifier.trim(),
        password: password,
      );
      final json = response.userEmail;
      _account = UserAccountDto(
        id: '',
        username: '',
        email: json.isNotEmpty ? json : identifier.trim(),
        emailVerified: true,
        phoneVerified: true,
        onboardingCompleted: true,
        status: '',
      );
      _userEmail = _account!.email;
      await _storage.saveSession(
        token: response.token,
        email: _userEmail,
      );
      // Hydrate real flags immediately (drives verification/onboarding routing).
      try {
        final profile = await apiClient.fetchProfile();
        _account = UserAccountDto(
          id: profile.userId,
          username: profile.username,
          email: profile.email,
          phone: profile.phone,
          emailVerified: profile.emailVerified,
          phoneVerified: profile.phoneVerified,
          onboardingCompleted: profile.onboardingCompleted,
          status: profile.status,
        );
        _userEmail = profile.email;
        await _storage.saveSession(token: response.token, email: profile.email);
      } catch (_) {
        // Flags load on next authenticated action.
      }
      _lastError = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return _account;
    } on ApiException catch (error) {
      _fail(_safe(error));
      return null;
    } catch (error) {
      _fail(NetworkException(error));
      return null;
    }
  }

  Future<UserAccountDto?> verifyEmail(String code) => _verify(
        () => apiClient.verifyEmail(code.trim()),
        isVerified: (account) => account.emailVerified,
      );

  Future<UserAccountDto?> verifyPhone(String code) => _verify(
        () => apiClient.verifyPhone(code.trim()),
        isVerified: (account) => account.phoneVerified,
      );

  Future<UserAccountDto?> _verify(
    Future<UserAccountDto> Function() call, {
    required bool Function(UserAccountDto) isVerified,
  }) async {
    _setBusy();
    try {
      final account = await call();
      _account = account;
      _userEmail = account.email;
      _lastError = null;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return account;
    } on ApiException catch (error) {
      // Stay authenticated: the session is valid, only the code failed.
      // Idempotency tolerance: a retried tap after a successful verify (or a
      // duplicate in-flight submit) hits a consumed code. Reload flags first:
      // if the channel is already verified, report success instead of an
      // INVALID_OTP error for an already-verified account.
      try {
        final profile = await apiClient.fetchProfile();
        final account = UserAccountDto(
          id: profile.userId,
          username: profile.username,
          email: profile.email,
          phone: profile.phone,
          emailVerified: profile.emailVerified,
          phoneVerified: profile.phoneVerified,
          onboardingCompleted: profile.onboardingCompleted,
          status: profile.status,
        );
        if (isVerified(account)) {
          _account = account;
          _userEmail = account.email;
          _lastError = null;
          _status = AuthStatus.authenticated;
          notifyListeners();
          return account;
        }
      } catch (_) {
        // Fall through to the original error below.
      }
      _lastError = _safe(error);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return null;
    } catch (error) {
      _lastError = NetworkException(error);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return null;
    }
  }

  /// Returns cooldown seconds on success; null on failure (see [lastError],
  /// including 429 with [ApiException.retryAfterSeconds]).
  Future<int?> resendEmailOtp() async {
    try {
      final issuance = await apiClient.resendEmailOtp();
      _lastError = null;
      notifyListeners();
      return issuance.cooldownSeconds;
    } on ApiException catch (error) {
      _lastError = _safe(error);
      notifyListeners();
      return null;
    } catch (error) {
      _lastError = NetworkException(error);
      notifyListeners();
      return null;
    }
  }

  Future<int?> resendPhoneOtp() async {
    try {
      final issuance = await apiClient.resendPhoneOtp();
      _lastError = null;
      notifyListeners();
      return issuance.cooldownSeconds;
    } on ApiException catch (error) {
      _lastError = _safe(error);
      notifyListeners();
      return null;
    } catch (error) {
      _lastError = NetworkException(error);
      notifyListeners();
      return null;
    }
  }

  /// Always resolves (generic server message prevents enumeration).
  Future<String?> forgotPassword({required String identifier, String? channel}) async {
    try {
      final message = await apiClient.forgotPassword(
        identifier: identifier.trim(),
        channel: channel,
      );
      _lastError = null;
      notifyListeners();
      return message;
    } on ApiException catch (error) {
      _fail(_safe(error));
      return null;
    } catch (error) {
      _fail(NetworkException(error));
      return null;
    }
  }

  Future<bool> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      await apiClient.resetPassword(
        identifier: identifier.trim(),
        code: code.trim(),
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _lastError = null;
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      _lastError = _safe(error);
      notifyListeners();
      return false;
    } catch (error) {
      _lastError = NetworkException(error);
      notifyListeners();
      return false;
    }
  }

  Future<UserProfileDto?> loadProfile() async {
    try {
      final profile = await apiClient.fetchProfile();
      _account = UserAccountDto(
        id: profile.userId,
        username: profile.username,
        email: profile.email,
        phone: profile.phone,
        emailVerified: profile.emailVerified,
        phoneVerified: profile.phoneVerified,
        onboardingCompleted: profile.onboardingCompleted,
        status: profile.status,
      );
      _userEmail = profile.email;
      _lastError = null;
      notifyListeners();
      return profile;
    } on ApiException catch (error) {
      _lastError = _safe(error);
      notifyListeners();
      return null;
    } catch (error) {
      _lastError = NetworkException(error);
      notifyListeners();
      return null;
    }
  }

  Future<void> logout() async {
    apiClient.token = null;
    try {
      await _storage.clear();
    } catch (_) {
      // Best effort: sign-out must never fail because of storage.
    }
    _userEmail = '';
    _account = null;
    _lastError = null;
    _justRegistered = false;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Marks onboarding complete on the backend and leaves wizard routing.
  Future<UserProfileDto?> completeOnboarding() async {
    try {
      final profile = await apiClient.completeOnboarding();
      _account = UserAccountDto(
        id: profile.userId,
        username: profile.username,
        email: profile.email,
        phone: profile.phone,
        emailVerified: profile.emailVerified,
        phoneVerified: profile.phoneVerified,
        onboardingCompleted: profile.onboardingCompleted,
        status: profile.status,
      );
      _justRegistered = false;
      _lastError = null;
      notifyListeners();
      return profile;
    } on ApiException catch (error) {
      _lastError = _safe(error);
      notifyListeners();
      return null;
    } catch (error) {
      _lastError = NetworkException(error);
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  void _setBusy() {
    _lastError = null;
    _status = AuthStatus.busy;
    notifyListeners();
  }

  void _fail(ApiException error) {
    _lastError = error;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Never surface internal/server details for 5xx.
  static ApiException _safe(ApiException error) {
    if (error.statusCode >= 500) {
      return ApiException(
        error.statusCode,
        error.code,
        'Something went wrong. Please try again.',
        fieldErrors: error.fieldErrors,
      );
    }
    return error;
  }
}
