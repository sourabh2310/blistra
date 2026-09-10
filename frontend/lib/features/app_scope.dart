/// InheritedWidget that provides app-wide dependencies down the widget tree.
library;

import 'package:flutter/material.dart';

import '../core/api/api_client.dart';
import '../core/auth/auth_state.dart';
import '../features/medicines/data/medicines_api_client.dart';

class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.apiClient,
    required this.authState,
    required this.medicinesApiClient,
    required super.child,
  });

  final ApiClient apiClient;
  final AuthState authState;
  final MedicinesApiClient medicinesApiClient;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) {
      throw FlutterError(
        'AppScope not found in context. Ensure the widget is a descendant of AppScope.',
      );
    }
    return scope;
  }

  @override
  bool updateShouldNotify(AppScope old) =>
      apiClient != old.apiClient ||
      authState != old.authState ||
      medicinesApiClient != old.medicinesApiClient;
}