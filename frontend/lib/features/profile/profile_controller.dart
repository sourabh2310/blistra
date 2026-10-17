/// Profile state for the Profile section and onboarding.
///
/// Wraps the identity-adjacent profile endpoints (GET/PUT /api/v1/profile,
/// photo, identity change, onboarding completion, change password, account
/// deletion) with loading and error states. Health measurements stay owned
/// by the Health domain.
library;

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';

class ProfileController extends ChangeNotifier {
  ProfileController(this._client);

  final ApiClient _client;

  UserProfileDto? _profile;
  bool _loading = false;
  bool _saving = false;
  bool _photoBusy = false;
  String? _error;
  Uint8List? _avatarBytes;
  int? _avatarBytesVersion;
  String? _owner;

  UserProfileDto? get profile => _profile;
  bool get loading => _loading;
  bool get saving => _saving;
  bool get photoBusy => _photoBusy;
  String? get error => _error;

  /// Photo bytes for the current profile, or null when there is none (or it
  /// is still downloading).
  Uint8List? get avatarBytes => _profile?.hasAvatar == true ? _avatarBytes : null;

  /// Drops everything cached for the previous user when the signed-in
  /// account changes, so the next user never sees someone else's profile,
  /// then loads the new user's profile (and photo for the header avatar).
  void bindOwner(String owner) {
    if (owner == _owner) return;
    _owner = owner;
    _profile = null;
    _avatarBytes = null;
    _avatarBytesVersion = null;
    _error = null;
    // Called from widget lifecycle hooks, so notify after the current build.
    // ignore: discarded_futures
    Future.microtask(() {
      notifyListeners();
      if (owner.isNotEmpty && owner == _owner) return load();
    });
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _client.fetchProfile();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Could not load your profile.';
    } finally {
      _loading = false;
      notifyListeners();
    }
    await _syncAvatar();
  }

  /// Downloads the photo when the server's version differs from the cached
  /// one. A failed download just leaves the initials avatar in place.
  Future<void> _syncAvatar() async {
    final p = _profile;
    if (p == null || !p.hasAvatar) {
      _avatarBytes = null;
      _avatarBytesVersion = null;
      return;
    }
    if (_avatarBytes != null && _avatarBytesVersion == p.avatarVersion) return;
    try {
      _avatarBytes = await _client.fetchAvatar();
      _avatarBytesVersion = p.avatarVersion;
      notifyListeners();
    } catch (_) {
      // Initials stay visible; the next load retries.
    }
  }

  Future<bool> save(Map<String, Object?> fields) =>
      _run(() async => _profile = await _client.updateProfile(fields),
          'Could not save your profile.');

  Future<bool> uploadAvatar(List<int> bytes, String filename) async {
    _photoBusy = true;
    notifyListeners();
    final ok = await _run(() async {
      _profile = await _client.uploadAvatar(bytes, filename);
      // Show the chosen photo right away instead of re-downloading it.
      _avatarBytes = Uint8List.fromList(bytes);
      _avatarBytesVersion = _profile?.avatarVersion;
    }, 'Could not upload your photo.');
    _photoBusy = false;
    notifyListeners();
    return ok;
  }

  Future<bool> removeAvatar() async {
    _photoBusy = true;
    notifyListeners();
    final ok = await _run(() async {
      _profile = await _client.removeAvatar();
      _avatarBytes = null;
      _avatarBytesVersion = null;
    }, 'Could not remove your photo.');
    _photoBusy = false;
    notifyListeners();
    return ok;
  }

  Future<bool> completeOnboarding() =>
      _run(() async => _profile = await _client.completeOnboarding(),
          'Could not complete onboarding.');

  Future<bool> changeIdentity({
    required String currentPassword,
    String? username,
    String? email,
    String? phone,
  }) =>
      _run(
        () async => _profile = await _client.updateIdentity(
          currentPassword: currentPassword,
          username: username,
          email: email,
          phone: phone,
        ),
        'Could not update sign-in details.',
      );

  Future<bool> confirmIdentity({required String code, String channel = 'EMAIL'}) =>
      _run(
        () async => _profile =
            await _client.confirmIdentity(code: code, channel: channel),
        'Could not confirm the change.',
      );

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) =>
      _run(
        () => _client.changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        ),
        'Could not change your password.',
      );

  /// Permanently deletes the account. The caller signs out on success.
  Future<bool> deleteAccount({required String currentPassword}) =>
      _run(() => _client.deleteAccount(currentPassword: currentPassword),
          'Could not delete your account.');

  Future<bool> _run(Future<void> Function() action, String fallback) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } on ApiException catch (e) {
      _error = e.fieldErrors.isNotEmpty
          ? e.fieldErrors.values.first
          : e.message == 'Request validation failed'
              ? 'We couldn\'t save your details. Please try again.'
              : e.message;
      return false;
    } catch (_) {
      _error = fallback;
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
