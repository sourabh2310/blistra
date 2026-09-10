/// Backward-compatible re-export.
///
/// The canonical scope lives in `app/app_scope.dart`. The dashboard/planner
/// screens historically import `features/app_scope.dart`; this shim keeps
/// those imports working without duplicating the scope implementation.
library;

export '../app/app_scope.dart';
