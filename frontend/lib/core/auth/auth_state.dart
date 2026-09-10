/// In-memory authentication session backed by the real backend API.
///
/// No fake or hard-coded credentials are ever used: registering and logging
/// in call the backend, and the returned JWT is stored in memory only.
library;

import 'package:flutter/foundation.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';

enum AuthStatus { unknown, authenticated, unauthenticated, busy }

class AuthState extends ChangeNotifier {
  AuthState({required this.apiClient});

  final ApiClient apiClient;

  AuthStatus _status = AuthStatus.unauthenticated;
  String _userEmail = '';
  ApiException? _lastError;

  AuthStatus get status => _status;
  String get userEmail => _userEmail;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  ApiException? get lastError => _lastError;

  Future<void> register(String email, String password) async {
    _setBusy();
    try {
      await apiClient.register(email, password);
      await login(email, password);
    } on ApiException catch (error) {
      _fail(error);
    } catch (error) {
      _fail(NetworkException(error));
    }
  }

  Future<void> login(String email, String password) async {
    _setBusy();
    try {
      final AuthResponseDto response = await apiClient.login(email, password);
      _userEmail = response.userEmail.isNotEmpty ? response.userEmail : email;
      _status = AuthStatus.authenticated;
      notifyListeners();
    } on ApiException catch (error) {
      _fail(error);
    } catch (error) {
      _fail(NetworkException(error));
    }
  }

  void logout() {
    apiClient.token = null;
    _userEmail = '';
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setBusy() {
    _status = AuthStatus.busy;
    notifyListeners();
  }

  void _fail(ApiException error) {
    _lastError = error;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}