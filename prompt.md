You are working on the Blistra repository.

Repository:
`https://github.com/sourabh2310/blistra`

Target branch:
`stabilization/integration-pass`

Your task is to perform a COMPLETE file-by-file audit and refactoring of the Flutter frontend under:

`frontend/`

Do NOT blindly rewrite the frontend.

First inspect every frontend file, understand the existing implementation, identify what is reusable, identify what is incomplete/wrong, and then implement the required changes.

The backend is already substantially implemented and must be treated as the source of truth for API contracts and domain behavior.

==================================================

1. PRIMARY OBJECTIVE
   ==================================================

Transform the existing Flutter frontend into a production-quality, feature-oriented Blistra application that integrates correctly with the existing Spring Boot backend.

Blistra V1 domains are:

1. Authentication
2. Dashboard
3. Planner
4. Health
5. Medicines
6. Diet
7. Habits
8. Finance

Additional infrastructure/features already present or planned:

9. Documents
10. Notifications
11. AI-ready architecture

The frontend must NOT be centered around Notifications.

Authentication, application shell, dashboard, planner, etc. must be independent features.

==================================================
2. FIRST STEP — COMPLETE FRONTEND AUDIT
=======================================

Before changing code, inspect EVERY file under:

frontend/lib/
frontend/test/
frontend/android/
frontend/ios/
frontend/web/
frontend/pubspec.yaml
frontend/analysis_options.yaml

and any other frontend configuration files.

Produce an internal inventory containing:

* file path
* purpose
* dependencies
* public classes/functions
* API calls
* state management
* navigation responsibilities
* reusable components
* technical debt
* bugs
* missing functionality
* duplicate functionality
* architecture violations

Do not delete working functionality without understanding it.

Preserve useful existing implementations where possible.

==================================================
3. TARGET FRONTEND ARCHITECTURE
===============================

Refactor toward:

lib/
├── main.dart
│
├── app/
│   ├── app.dart
│   ├── app_router.dart
│   ├── app_dependencies.dart
│   └── theme/
│
├── core/
│   ├── api/
│   │   ├── api_client.dart
│   │   ├── api_exception.dart
│   │   ├── api_response.dart
│   │   └── api_interceptor.dart
│   │
│   ├── auth/
│   │   ├── auth_storage.dart
│   │   └── auth_session.dart
│   │
│   ├── constants/
│   ├── networking/
│   ├── routing/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── dashboard/
│   ├── planner/
│   ├── health/
│   ├── medicines/
│   ├── diet/
│   ├── habits/
│   ├── finance/
│   ├── documents/
│   └── notifications/
│
└── shared/
├── widgets/
├── models/
└── extensions/

You may adjust this structure when the existing codebase provides a better equivalent.

Do not create architecture purely for the sake of creating folders.

==================================================
4. CRITICAL ARCHITECTURE FIX
============================

The current frontend application bootstrap is centered around:

notifications/

including:

* notifications/screens/auth_screen.dart
* notifications/screens/home_shell.dart
* notifications/state/auth_controller.dart
* notifications/state/reminders_controller.dart
* notifications/state/settings_controller.dart

This is architecturally incorrect.

Move authentication into:

features/auth/

Move the main application shell/navigation into:

app/

Move dashboard into:

features/dashboard/

Move notification functionality into:

features/notifications/

Notifications must NOT own authentication or the entire application shell.

==================================================
5. MAIN.DART
============

Reduce main.dart to application bootstrap only.

It should not contain substantial application logic.

Target responsibility:

* Flutter binding initialization
* dependency initialization
* runApp()

Move configuration and service initialization into appropriate classes.

Do not initialize notification permission dialogs blindly during application startup.

==================================================
6. APPLICATION SHELL
====================

Create a proper Blistra application shell.

The shell should support:

* Dashboard
* Planner
* Health
* Medicines
* Diet
* Habits
* Finance
* Documents
* Notifications/settings where appropriate

Design the navigation for mobile first.

The application must also remain structurally compatible with tablet/web layouts.

Do not build separate unrelated navigation systems for each feature.

Use a single application routing strategy.

==================================================
7. THEME / DESIGN SYSTEM
========================

Create a consistent Blistra Material 3 design system.

Centralize:

* colors
* typography
* spacing
* border radius
* button styles
* cards
* input fields
* dialogs
* loading indicators
* empty states
* error states

Avoid hard-coding visual constants repeatedly across screens.

The UI should feel like one application, not a collection of unrelated Flutter examples.

Keep the design clean, modern, mobile-first and information-dense without being cluttered.

==================================================
8. API CLIENT
=============

Create one centralized HTTP API client.

Backend API base path:

`/api/v1`

The API client must support:

* GET
* POST
* PUT
* PATCH
* DELETE
* multipart upload
* binary/file downloads

It must automatically attach the authenticated JWT when required.

Do not duplicate token/header logic in every feature.

Use appropriate timeouts.

Handle:

* connection failures
* timeout
* malformed responses
* HTTP errors
* unauthorized responses
* server errors

==================================================
9. API ERROR MODEL
==================

The backend uses structured error responses.

Support fields equivalent to:

* timestamp
* status
* code
* message
* path
* errors

Support field-level validation errors.

Create a typed Flutter ApiException.

Map backend errors to user-friendly UI behavior.

Never display raw stack traces or internal server exceptions to users.

For generic 500 errors show a safe message.

==================================================
10. AUTHENTICATION
==================

Integrate with:

POST /api/v1/auth/register
POST /api/v1/auth/login

Implement:

* registration
* login
* logout
* session restoration
* JWT persistence
* authentication state
* expired session handling
* 401 handling

Do not use ordinary SharedPreferences as the preferred secure storage mechanism for sensitive authentication credentials where a secure platform storage option is appropriate.

Use secure storage for Android/iOS.

For web, use an architecture appropriate to browser security constraints and do not pretend that web local storage provides equivalent security to native secure storage.

Do not store passwords.

After successful login:

login
→ persist token/session
→ update auth state
→ open application shell

After logout:

clear credentials
→ clear authenticated state
→ return to login

==================================================
11. DASHBOARD
=============

Implement Dashboard as the primary Blistra home screen.

It should be designed to eventually aggregate:

* today's planner tasks
* habit progress
* medication reminders
* health information
* diet information
* finance snapshot
* upcoming items

Do not duplicate domain ownership in Dashboard.

Dashboard is an aggregation/presentation layer.

Planner owns planner data.
Habits owns habit data.
Medicines owns medication data.
Finance owns finance data.

==================================================
12. PLANNER
===========

Integrate with the existing Planner backend.

Support:

* task lists
* tasks
* create
* edit
* delete
* complete
* reopen
* cancel
* priority
* status
* due date
* due time
* Today
* Upcoming
* Overdue
* Active
* Completed
* pagination

Respect backend semantics.

Do NOT implement separate client-side business rules that conflict with the backend.

Models must match backend DTOs.

Support:

loading
empty
error
success

states.

Task ownership is handled by the backend.

==================================================
13. HEALTH
==========

Inspect the backend Health API and implement Flutter integration based on the actual backend DTOs/endpoints.

Do not invent endpoint names.

Support the existing Health domain.

Create:

* models
* API service
* repository/application layer if appropriate
* controller/provider/notifier
* screens
* forms
* validation
* loading/error/empty states

Keep health information clearly separated from Medicines.

==================================================
14. MEDICINES
=============

Inspect the backend Medicines module and integrate it exactly.

Support the existing medication model and schedule behavior.

Implement:

* medication list
* medication details
* create
* edit
* delete
* schedules
* relevant reminder UI
* validation
* loading/error/empty states

Do not duplicate medical/business rules unnecessarily in Flutter.

==================================================
15. DIET
========

Inspect the backend Diet module first.

Integrate actual backend DTOs and endpoints.

Support the V1 Diet functionality that exists in the backend.

Create clean screens and reusable components.

Do not invent unsupported backend capabilities.

==================================================
16. HABITS
==========

Inspect the backend Habits module first.

Integrate actual endpoints/models.

Support:

* habit list
* creation
* editing
* completion/check-in
* relevant streak/progress information
* loading
* errors
* empty states

Respect backend integrity rules.

==================================================
17. FINANCE
===========

Inspect the backend Finance module first.

Implement the Flutter client based on actual endpoints/DTOs.

Support the V1 finance functionality currently implemented.

Include:

* transactions
* categories where supported
* income/expense representation
* totals
* filters
* relevant summaries

Do not invent UPI/SMS functionality unless the backend currently exposes it.

UPI and SMS ingestion should be architected as future platform/integration capabilities.

==================================================
18. DOCUMENTS
=============

Integrate the existing Documents backend.

Existing backend operations include:

POST /api/v1/documents
GET /api/v1/documents
GET /api/v1/documents/{id}
GET /api/v1/documents/{id}/content
PATCH /api/v1/documents/{id}
DELETE /api/v1/documents/{id}

Support:

* file picker
* upload
* category
* description
* list
* pagination
* filtering
* metadata view
* download
* open file
* update metadata
* delete

Use multipart upload correctly.

Handle:

* file too large
* unsupported file
* upload failure
* download failure
* authentication failure

Do not expose storage paths.

==================================================
19. NOTIFICATIONS
=================

Keep notifications as an independent feature.

Implement a notification/reminder service that can be invoked by:

* Medicines
* Planner
* Habits
* other reminder-producing features

Do not make Notifications the parent of these features.

Do not request notification permissions aggressively on application startup.

Request permissions in a context where the user understands why permission is needed.

Support local notifications using the existing dependencies where appropriate.

Respect timezone configuration.

==================================================
20. SETTINGS
============

Create an appropriate settings area.

Potential settings:

* profile
* timezone
* notification preferences
* appearance
* logout

Only implement backend-backed settings when the backend supports them.

Do not invent APIs.

==================================================
21. STATE MANAGEMENT
====================

The current project uses Provider.

You may continue using Provider if it is already working well.

Do not introduce another state-management framework simply for preference.

Use consistent patterns.

Example:

Feature UI
→ Controller/ViewModel
→ Repository
→ API service
→ ApiClient

Avoid putting HTTP calls directly inside widgets.

Controllers should expose explicit state:

loading
success
empty
error

where appropriate.

==================================================
22. MODELS
==========

Create typed models matching backend DTOs.

Do not use Map<String, dynamic> throughout the application.

Each feature should have explicit request/response models.

Implement:

fromJson()
toJson()

where needed.

Be careful with:

* UUIDs
* dates
* times
* OffsetDateTime/ISO-8601
* nullable values
* enums
* pagination

Do not silently change backend enum names.

==================================================
23. DATE/TIME
=============

Backend timestamps are handled consistently with UTC and user-facing timezone conversion.

Flutter must:

* parse ISO-8601 correctly
* preserve offsets
* display user-local time
* avoid hard-coded Asia/Kolkata logic in the application
* use configured user timezone when available

Do not use string manipulation for date/time conversion.

==================================================
24. PAGINATION
==============

Implement reusable pagination support.

Do not hard-code one pagination implementation per feature.

Create reusable pagination models/helpers.

Support:

* initial load
* next page
* refresh
* end of list
* loading next page
* error loading next page

==================================================
25. LOADING / ERROR / EMPTY UX
==============================

Every major feature must have:

Loading state
Empty state
Error state
Success state

Avoid blank screens.

Provide retry actions where appropriate.

Do not show raw exceptions.

==================================================
26. FORMS
=========

Create consistent form components.

Forms must have:

* validation
* disabled submit while saving
* loading indicator
* backend validation error handling
* keyboard-friendly mobile behavior
* proper date/time selectors
* confirmation for destructive actions where appropriate

==================================================
27. ACCESSIBILITY
=================

Add:

* semantic labels
* sufficient touch target sizes
* readable typography
* appropriate contrast
* keyboard navigation where applicable
* screen-reader-friendly controls

Do not rely exclusively on color to convey status.

==================================================
28. RESPONSIVE DESIGN
=====================

Android is the highest-priority platform.

But design the application so it works on:

* small Android phones
* large Android phones
* tablets
* web

Do not simply stretch mobile UI onto desktop.

Use responsive layouts where appropriate.

==================================================
29. SECURITY
============

Never:

* log JWT tokens
* log passwords
* log sensitive personal information
* hard-code secrets
* hard-code production credentials
* trust frontend authorization

The backend remains the authorization boundary.

==================================================
30. CONFIGURATION
=================

Keep:

API_BASE_URL

configurable using dart-define.

For example:

--dart-define=API_BASE_URL=http://10.0.2.2:8080

Do not hard-code production API URLs.

Provide sensible development defaults only.

==================================================
31. TESTING
===========

Inspect the existing frontend tests first.

Add/update tests for:

* authentication
* API client
* API errors
* token/session handling
* Planner models/services/controllers
* Dashboard
* Health
* Medicines
* Diet
* Habits
* Finance
* Documents
* Notifications
* routing/auth gate

Tests must not depend on a live backend unless specifically intended as integration tests.

Mock API/network boundaries.

==================================================
32. FLUTTER QUALITY
===================

After modifications run:

flutter pub get
flutter analyze
flutter test

Fix ALL analyzer errors.

Fix ALL test failures.

Do not suppress warnings just to make CI green.

Avoid:

* unnecessary dynamic
* unnecessary casts
* dead code
* duplicate widgets
* giant StatefulWidgets
* API calls from build()
* business logic inside UI widgets

==================================================
33. DEPENDENCIES
================

Inspect pubspec.yaml.

Remove dependencies that are genuinely unused.

Keep dependencies that are required by the existing implementation.

Do not add large packages without a clear reason.

Prefer Flutter/Dart standard functionality where practical.

If secure credential storage is needed, add the appropriate package and configure Android/iOS/web correctly.

==================================================
34. DO NOT INVENT BACKEND APIs
==============================

This is extremely important.

Before implementing a feature:

1. Inspect the corresponding backend module.
2. Inspect its controller.
3. Inspect request DTOs.
4. Inspect response DTOs.
5. Inspect enums.
6. Inspect pagination.
7. Inspect error behavior.
8. Then implement Flutter integration.

Do not guess endpoint names.

Do not create frontend models based only on assumptions.

The backend is the source of truth.

==================================================
35. DO NOT BREAK EXISTING BACKEND
=================================

This task is primarily frontend work.

Do not modify backend code unless absolutely necessary for a genuine frontend integration blocker.

If a backend problem is discovered:

* document it
* identify exact file/API
* explain why it blocks frontend
* make the smallest safe fix only if required

Do not perform unrelated backend refactoring.

==================================================
36. FILE-BY-FILE CHANGE LOG
===========================

After completing the work, provide a report:

For every changed file:

FILE:
CHANGE:
REASON:
DEPENDENCIES:
TESTING:

Also provide:

A. Files created
B. Files modified
C. Files deleted
D. Files intentionally preserved
E. Backend integration assumptions
F. Known remaining limitations

==================================================
37. FINAL ACCEPTANCE CRITERIA
=============================

The frontend is considered complete for this task only when:

[ ] Application has clean feature-oriented architecture
[ ] Notifications no longer own auth/application shell
[ ] main.dart is minimal
[ ] Central API client exists
[ ] JWT/session lifecycle works
[ ] API errors are typed and handled
[ ] Dashboard exists
[ ] Planner is integrated
[ ] Health is integrated
[ ] Medicines is integrated
[ ] Diet is integrated
[ ] Habits is integrated
[ ] Finance is integrated
[ ] Documents are integrated
[ ] Notifications are independent
[ ] Loading states exist
[ ] Empty states exist
[ ] Error states exist
[ ] Forms are validated
[ ] Pagination is handled
[ ] Date/time handling is correct
[ ] No sensitive data is logged
[ ] No backend authorization is duplicated as trusted logic
[ ] Flutter analyze passes
[ ] Flutter tests pass
[ ] Existing functionality that remains valid is preserved
[ ] No fake/mock production functionality is left accidentally
[ ] No unsupported backend endpoints are invented

==================================================
38. IMPORTANT WORKING STYLE
===========================

Do NOT try to complete this by generating a giant replacement frontend blindly.

Work incrementally:

Phase 1:
Audit

Phase 2:
Core architecture/API/auth

Phase 3:
Application shell/navigation/theme

Phase 4:
Dashboard

Phase 5:
Planner

Phase 6:
Health

Phase 7:
Medicines

Phase 8:
Diet

Phase 9:
Habits

Phase 10:
Finance

Phase 11:
Documents

Phase 12:
Notifications

Phase 13:
Tests/cleanup

After each major phase:

* run analyzer
* run relevant tests
* fix regressions

Keep the code compiling throughout the process.

Do not leave the repository in a half-migrated state.

==================================================
39. FINAL OUTPUT
================

At the end, report:

1. Architecture before
2. Architecture after
3. Complete file-by-file change list
4. Backend APIs integrated
5. Features completed
6. Features still incomplete
7. Tests executed
8. flutter analyze result
9. flutter test result
10. Any backend blockers
11. Any recommended next steps

Do not claim something is implemented unless the code actually implements it.

Do not claim tests pass unless they were actually executed.
