/// Home integration for the Medicines feature.
library;

import 'package:flutter/widgets.dart';

import '../../app_scope.dart';

/// Refreshes the Home dashboard after a successful Medicines mutation so the
/// Home Medicines card (and Planner's aggregated doses, which read the same
/// dashboard payload) stop showing stale data.
///
/// Never throws: without a scope (e.g. widget tests) or while offline,
/// Medicines itself stays correct.
Future<void> refreshHomeDashboard(BuildContext context) async {
  try {
    await AppScope.of(context).dashboard.refresh(
          date: DateTime.now(),
          offsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
        );
  } catch (_) {
    // No scope or transient network: Medicines stays correct.
  }
}
