/// Profile state for the Profile section and onboarding.
///
/// Wraps the identity-adjacent profile endpoints (GET/PUT /api/v1/profile,
/// identity change, onboarding completion, change password) with loading and
/// error states. Health measurements stay owned by the Health domain; this
/// controller only reads the health profile for display.
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
  String? _error;

  UserProfileDto? get profile => _profile;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

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
  }

  Future<bool> save(Map<String, Object?> fields) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _client.updateProfile(fields);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Could not save your profile.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> completeOnboarding() async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _client.completeOnboarding();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Could not complete onboarding.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> changeIdentity({
    required String currentPassword,
    String? username,
    String? email,
    String? phone,
  }) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _client.updateIdentity(
        currentPassword: currentPassword,
        username: username,
        email: email,
        phone: phone,
      );
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Could not update sign-in details.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> confirmIdentity({required String code, String channel = 'EMAIL'}) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _client.confirmIdentity(code: code, channel: channel);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Could not confirm the change.';
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _client.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Could not change your password.';
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
