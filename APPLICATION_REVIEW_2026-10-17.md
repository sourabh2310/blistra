# Blistra application review

**Review date:** 17 October 2026 (Asia/Calcutta)  
**Repository snapshot:** `4ab7954`, branch `fix/auth-mobile-ux`  
**Review type:** Read-only source, configuration, documentation, test-artifact, and design-reference review  
**Deliverable:** This report only. No application changes were made.

## 1. Executive assessment

Blistra has a substantial implementation of a personal life-management product: a shared dashboard, planner, health records, medicines, diet and water tracking, habits, expenses and expense splitting, document storage, profile management, search, preferences, and reminders. Its feature-oriented Flutter client, Spring Boot modular monolith, relational migrations, ownership checks, and exact money arithmetic provide a useful foundation.

**Recommendation: continue development and controlled testing; do not treat the reviewed configuration as ready for a public production launch with important personal data.** The immediate priority is trust and correctness across existing features. Adding more modules would increase the support burden before the current promises are reliable.

The most consequential problems are:

1. **Uploaded documents and profile photos can disappear on server restart or redeployment.** The supplied Render deployment uses ephemeral local storage. The deployment documentation acknowledges this limitation, but users encounter a private document vault without equivalent in-product protection.
2. **Documents have broken viewing and failure-handling paths.** The detail screen requests a repository absent from the provider graph; failed uploads can close the form as though they succeeded.
3. **Optional phone collection can prevent onboarding completion.** The client skips SMS verification by default, while the backend requires it whenever a phone number exists.
4. **Reminder behavior does not meet the apparent product promise.** Required Android receivers are missing, medicine schedules do not generate medicine reminders, and the active sign-out flow does not cancel local reminders.
5. **Session boundaries need strengthening.** Shared controllers retain previous-account data, password reset does not invalidate existing tokens, and no general login throttling was found in the application.
6. **Release gates are insufficient.** The APK workflow can publish with a debug signing key, runs only four frontend test files, and does not gate deployment on backend tests.

These findings do not establish that an attacker has exploited the system or that a deployed service has already lost data. They describe the inspected implementation and the supplied deployment path.

## 2. Scope, method, and limits

### What was reviewed

- Product vision, architecture, deployment and security documentation, README, architecture decisions, and repository structure.
- Authentication, registration, verification, recovery, JWT handling, profile changes, account deletion, and local session storage.
- Application bootstrap, dependency providers, navigation, shared state, network handling, and representative feature screens/controllers.
- Document upload/download/deletion, storage validation, filesystem behavior, profile photos, and client previews.
- Reminder persistence, device scheduling, medicine schedules and dose recording, and task reminder integration.
- Finance ownership, sharing, settlement behavior, splitting, currency handling, and exact arithmetic.
- Representative dashboard, search, habits, diet, health, planner, and timezone paths.
- Database migrations, production/development settings, Docker, Render configuration, Android signing/build automation, platform scaffolding, and test sources/artifacts.
- `Homepage.png` and `Page UI/Medicines Page.png` as design references. These are not evidence of the current running UI.

### Review discipline

Only file reads, searches, hashing, Git inspection, and public documentation lookups were used before creating this report. No servers, containers, builds, tests, migrations, package installations, account actions, API mutations, or application UI sessions were started. Existing untracked `.claude/` content was left alone.

This is a broad, risk-focused review, not an exhaustive line-by-line audit or a penetration test. Findings marked **confirmed** follow directly from source/configuration. **Inferred** findings have a concrete code mechanism but need a targeted runtime test. **Unverified controls** may exist outside this repository.

The review cannot establish live hosting settings, backup availability, database encryption, external firewall/rate-limit rules, secret rotation history, actual user traction, device performance, accessibility conformance, legal compliance, or the complete vulnerability status of dependency trees. No secrets or personal database records were collected. No legal, medical, or investment conclusions are made here.

### Existing verification evidence

| Evidence | Observation | Interpretation |
|---|---|---|
| Backend test-source inventory | 72 Java files under `backend/src/test` | Includes support classes; this is not a test-case count. |
| Frontend test-source inventory | 34 Dart files under `frontend/test` | Includes a live contract test requiring explicit environment configuration. |
| Existing Surefire XML reports | 67 report files, recording 549 tests, zero failures/errors/skips | Historical artifacts only; not a fresh execution against this review. |
| Artifact freshness caveat | At least one report names a temporary live-check suite absent from current test sources | The report set is not proof that exactly the present tree passed one clean run. |
| APK workflow test step | Four named frontend test files | Much narrower than the available suite. |
| New tests/builds during review | None | Preserves the requested read-only application review. |

### Severity interpretation

- **High:** resolve before relying on the affected feature in a public launch; threatens sensitive-data trust, recovery, delivery, or a core journey.
- **Medium:** material correctness, operational, privacy, or usability weakness; schedule explicitly and set a release condition where applicable.
- Suggested checks below are future acceptance tests. They were not executed during this review.

## 3. Product and user perspective

### What works well conceptually

The shared Home view, global quick-add, search, domain pages, and customizable navigation address a real convenience problem: users otherwise move between several separate trackers. Bringing scheduled tasks, habits and medicines into one daily view could create more value than presenting a launcher for unrelated modules.

There are thoughtful implementation details: domain ownership checks, explicit empty/error states, some semantic labels and tooltips, server-derived user identity, deterministic money splitting, user-controlled navigation, and distinguishing unrecorded medicine doses from explicitly missed doses. These should be preserved.

### Core journey assessment

| Journey | Existing support | Main friction/risk | Desired outcome |
|---|---|---|---|
| First registration | Wizard, availability checks, email OTP, profile/health setup | Long form before first value; phone/SMS mismatch; policy text cannot be opened | A user can reach one useful daily action with minimal required information. |
| Return to app | Persisted session, background profile hydration, Home | Expired sessions depend on request failure; state is not isolated by account | Correct account data and an understandable loading/offline state. |
| Plan the day | Tasks, lists, events, integrated Home and Planner | Timezone disagreement and reminder limitations | Date/time and reminder status agree across screens. |
| Track medicines | Medicine records, schedules, today slots, history | Scheduling is not connected to medicine notification generation | Clear distinction between a recorded schedule and a working alert. |
| Record food/water/habits | Dedicated forms, summaries, quick actions | Manual-entry burden and no demonstrated offline write queue | Fast repeat entry and recoverable failed saves. |
| Split expenses | Friend consent, shared expenses, multiple split modes, settlements | Silent edits/deletes; unilateral settlement recording; precision display | Both participants can understand how a balance changed. |
| Keep documents | Upload, metadata, filtering, download APIs | Ephemeral storage, missing provider, false-success upload flow | An uploaded document remains retrievable and failures stay visible. |
| Leave/delete account | Password-confirmed deletion and finance anonymization | Local reminders/caches and failed file cleanup can remain | An explicit, testable account and device cleanup boundary. |

### UX, accessibility, and visual review

The reference images communicate a calm, cohesive visual identity, but contain dense cards, several simultaneous indicators, fine text, and decorative space before daily actions. Treat these as hypotheses to validate against the implemented screens, not as proof of usability.

Recommended user testing:

- Ask first-time users to add a task, log water, record a dose, retrieve a document, and correct a shared expense without instructions. Record completion, confusion, and recovery from mistakes.
- Prioritize the next actionable item over generic motivational copy. Keep health status factual: missing readings are not evidence that everything is healthy.
- Check at 320–360 logical-pixel widths, landscape, large text, keyboard open, dark mode, and poor network conditions.
- Use TalkBack/VoiceOver and keyboard traversal for all key flows. Existing semantics are a good start; chart meanings, dose status, error announcements, focus order, and tap targets still need device validation.
- Provide a consistent way back from modules. Documents still exposes a module-level sign-out action while profile has a separate confirmation flow.
- Make critical failures persistent and specific. A brief toast is insufficient for an unsaved document or a reminder that was never scheduled.
- Show freshness and provenance on health/diet summaries: recorded time, missing inputs, and whether figures are manually entered or derived.

## 4. Business and strategy perspective

### Positioning and focus

“Everything you need. One app.” is broad enough to make scope and customer acquisition difficult to evaluate. The repository explains the vision, but does not establish a first customer segment, measured retention, willingness to pay, acquisition cost, or a repeatable sales/distribution channel.

A reasonable **product hypothesis**, not a validated market conclusion, is to start with people managing a daily routine across tasks, medicines and habits, with Home as the central workflow. Expense splitting serves a different social use case; it should have its own success criteria instead of being assumed to strengthen the same retention loop.

Choose one primary promise and demonstrate it before expanding Goals or AI. Differentiate through reliable cross-domain daily coordination and user trust. A large module count alone does not show that users will replace their current tools.

### Commercial questions that remain open

| Area | Current evidence | Decision needed |
|---|---|---|
| Primary customer | Broad personal-life vision; Android-first intent | Identify one initial segment and its most frequent problem. |
| Activation | Registration and onboarding implemented | Define the first meaningful outcome, then measure time to reach it. |
| Retention | Recurring tasks/habits/medicines support repeat use | Measure useful repeat actions, not app openings alone. |
| Monetization | No billing/entitlement implementation found in reviewed paths | Test willingness to pay before building a payment system. |
| Distribution | Sideloaded Android APK and in-app update flow | Decide supported channels, signing ownership, and support obligations. |
| Costs | API + PostgreSQL + email + local notifications + file storage | Model storage, downloads, email abuse, backups, support, and compute per active user. |
| Trust | Sensitive health, financial, identity and document data together | Fund reliability, privacy operations and incident response as product requirements. |
| Support | FAQ and optional compile-time support email | Give every shipped build a working escalation path. |

Possible pricing experiments include a free personal daily workflow and paid convenience/storage features. These are hypotheses only; no competitor pricing or demand study was performed. Recovery, account deletion, and basic security should remain available regardless of pricing.

### Measurement plan

Collect minimal event metadata without health values, document contents, raw search terms, medicine names or finance descriptions. Define:

- **Activation:** verified account plus completion of a chosen first useful action.
- **Time to value:** elapsed time from first launch to that action; include cold-start/network delays.
- **Retention:** weekly cohorts returning to complete a useful action on multiple days.
- **Workflow reliability:** successful save, read-back and correction rates by feature.
- **Reminder reliability:** scheduled/delivered/opened where the platform permits measurement, permission denial, and reconciliation failures.
- **Trust indicators:** recovery success, deletion completion, file retrieval failure, support contacts, and notification leaks after sign-out.
- **Economics:** cost per active account, per retained account, and per stored/downloaded GB.

Set targets from an initial controlled pilot. There is insufficient evidence to claim product-market fit or predict revenue.

## 5. Detailed findings

### F01 — High — Documents and photos use ephemeral production storage

**Status:** Confirmed for the supplied deployment configuration.

The Docker image sets `DOCUMENTS_STORAGE_ROOT=/tmp/blistra-documents`; Render uses `plan: free` without a persistent disk or an object-storage backend. Profile photos reuse the same storage abstraction. Database metadata survives separately, so an apparently existing document/photo can lose its bytes. The deployment guide explicitly acknowledges temporary document storage, which is useful operator disclosure but does not make a vault safe for important uploads.

**Evidence:** [Docker storage default](C:/Users/patel/Personal_Data/blistra/backend/Dockerfile:17), [Render service](C:/Users/patel/Personal_Data/blistra/render.yaml:9), [photo storage](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/profile/application/ProfileAvatarService.java:60), [deployment limitations](C:/Users/patel/Personal_Data/blistra/docs/deployment.md). Render documents filesystem loss on restart, redeployment and idle spin-down in its [free-service documentation](https://render.com/docs/free).

**Action and check:** Use durable private object storage or an appropriate persistent volume with backups and a restore process. Upload a file and photo, restart/redeploy the service, and verify exact-byte retrieval. Until then, make the temporary nature explicit before upload or keep the feature out of a production release.

### F02 — High — Document preview and open request an unavailable provider

**Status:** Confirmed source wiring defect.

`DocumentDetailPage` calls `context.read<DocumentsRepository>()` for image previews and downloads. The root graph provides `DocumentsProvider`, which privately owns that repository, but never registers `DocumentsRepository` itself. No other registration was found in `frontend/lib`. These paths therefore encounter `ProviderNotFoundException`; their catch blocks display errors rather than retrieving the document.

**Evidence:** [detail dependencies](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/documents/document_detail_page.dart:38), [root providers](C:/Users/patel/Personal_Data/blistra/frontend/lib/app/app.dart:53), [repository construction](C:/Users/patel/Personal_Data/blistra/frontend/lib/app/app_dependencies.dart:141).

**Action and check:** Expose the intended dependency or route downloads through the existing state abstraction. Open a PNG preview and a PDF from both Documents and search using the actual application provider graph.

### F03 — High — Failed uploads can exit as successful

**Status:** Confirmed control-flow defect.

`DocumentsProvider.upload()` catches errors and returns `null`. `UploadDocumentPage._upload()` ignores the returned document and unconditionally pops the page with `true`. A network failure, server validation failure or storage error can therefore close the upload form and discard the user's input without a successful upload.

**Evidence:** [nullable upload result](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/documents/providers/documents_provider.dart:92), [caller assumes success](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/documents/upload_document_page.dart:80).

**Action and check:** Keep the form open unless a real document is returned; preserve selection and metadata, show the error, and allow retry. Test HTTP 413, HTTP 500, offline operation and a successful upload/read-back.

### F04 — High — Optional phone registration conflicts with mandatory backend verification

**Status:** Confirmed contract mismatch under default production settings.

The client defaults `REQUIRE_PHONE_VERIFICATION` to false, allowing the wizard to skip SMS verification. Production defaults SMS delivery to disabled. However, `completeOnboarding()` requires a verified phone whenever a phone was provided, and activation uses the same requirement. A user who voluntarily supplies a phone can reach the end of setup and be unable to finish.

**Evidence:** [client flag](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/config/app_config.dart:24), [production SMS configuration](C:/Users/patel/Personal_Data/blistra/backend/src/main/resources/application-prod.yml:51), [completion requirements](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/profile/application/ProfileService.java:224), [activation](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/application/AuthService.java:450).

**Action and check:** Define one server-owned verification policy and expose capabilities to the client. Test new registration with and without a phone, with SMS disabled and enabled, through completion and subsequent login.

### F05 — Medium — Pending accounts receive broad authenticated access

**Status:** Confirmed behavior; policy decision required.

Registration issues a normal bearer token to a pending account. User loading rejects blocked accounts but accepts pending accounts, and API authorization generally requires only authentication. Restarting/logging in also routes non-fresh registrations into the shell. Consequently, verification/onboarding are not general server-enforced gates for domain access.

**Evidence:** [registration token](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/application/AuthService.java:178), [principal resolution](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/security/CustomUserDetailsService.java:30), [API authorization](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/config/SecurityConfig.java:93), [gate routing](C:/Users/patel/Personal_Data/blistra/frontend/lib/app/app.dart:137).

**Action and check:** Decide explicitly which features an unverified account may use. Enforce restricted account status on the server where needed, particularly uploads, friend requests and messaging-cost operations. Test direct API calls with a freshly registered token. This finding does not imply cross-user access.

### F06 — High — Android scheduled-notification receivers are missing

**Status:** Confirmed source configuration gap; device delivery not exercised.

The Android manifest includes notification and boot permissions but omits `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`. Both were also absent from the existing generated app manifests inspected, although those artifacts may predate the current source. Permissions alone do not register delivery/reboot handling.

**Evidence:** [application manifest](C:/Users/patel/Personal_Data/blistra/frontend/android/app/src/main/AndroidManifest.xml:1), [scheduler](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/notifications/services/flutter_notification_scheduler.dart:64). The locked plugin version is 19.5.0; its [maintainer documentation](https://pub.dev/packages/flutter_local_notifications/versions/19.5.0) requires these receivers for scheduling and reboot support.

**Action and check:** Follow the installed plugin's Android setup, inspect a freshly merged release manifest, then verify delivery while backgrounded and after reboot. Treat the selected inexact alarm mode as a timing limitation to communicate and test.

### F07 — High — Medicine schedules do not create medicine reminders

**Status:** Confirmed integration gap in reviewed production paths.

Medicine schedules expand into today-dose rows but do not create reminder records or directly schedule local notifications. `ReminderService.create()` allows only general reminders; task integration has an explicit reconciliation path, while medicines has no equivalent. The Medicines UI nevertheless directs users to manage medicine reminders.

**Evidence:** [medicine occurrence calculation](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/medicines/application/MedicineTodayService.java:77), [allowed reminder creation](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/notifications/application/ReminderService.java:47), [task integration](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/notifications/application/ReminderService.java:132), [medicine reminder copy](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/medicines/pages/medicine_list_page.dart:277).

**Action and check:** Connect medicine schedules to reminder generation and cancellation, including recurrence, pause/archive and timezone changes. Until working, label schedules as tracking-only. Create a daily schedule, inspect expected reminders and verify actual device delivery without reopening the app each day.

### F08 — High — Sign-out and session expiry do not cancel local notifications

**Status:** Confirmed lifecycle gap.

The active `AuthState.logout()` and unauthorized handler clear credentials but never call notification cancellation. The older notifications-specific controller does call `clearAll()`, but is not the root authentication controller. After account A signs out, A's locally scheduled content can still appear on the device. Logging in as B does not help: reconciliation only cancels IDs returned for B.

**Evidence:** [current logout](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/auth/auth_state.dart:382), [unauthorized handling](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/auth/auth_state.dart:101), [old cleanup path](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/notifications/state/auth_controller.dart:65), [ID-based reconciliation](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/notifications/services/reminder_sync_service.dart:51).

**Action and check:** Persist device-local scheduled IDs and cancel them on logout, expiry, deletion and account switch without requiring a live API. Test scheduling followed by offline logout, expiry and switching users. Content-hiding preferences reduce exposure but do not replace cleanup.

### F09 — High — Feature state and routes are not fully isolated by session

**Status:** Confirmed retained state; cross-account display is strongly inferred and should be reproduced.

Feature controllers are created once above the auth gate. Logout does not clear dashboard, planner, finance, diet, habits, health or document state. Several controllers keep old data while loading or on failure; in-flight requests generally lack a session-owner check. The Documents module's sign-out also leaves its pushed route on the root Navigator, relying on the underlying auth gate to change the home page.

**Evidence:** [application lifetime providers](C:/Users/patel/Personal_Data/blistra/frontend/lib/app/app.dart:50), [logout](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/auth/auth_state.dart:382), [retained documents](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/documents/providers/documents_provider.dart:16), [documents sign-out](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/documents/documents_page.dart:267), [finance state](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/finance/finance_controller.dart:32).

**Action and check:** Reset routes and sensitive state at every session boundary, and reject responses whose session owner has changed. Load A's data, delay an A response, sign out, sign in as B with network failure, and verify no A content is visible or applied. Add the same check for account deletion.

### F10 — High — Password recovery does not revoke existing access tokens

**Status:** Confirmed token-validation design.

Password reset/change replaces the password hash, but JWT validation checks signature and expiry and resolves the current user without comparing a token/session version or password-change timestamp. A stolen token can remain valid after a successful reset for its remaining lifetime, which defaults to 24 hours. Client logout also has no server revocation endpoint. Blocking/deleting a user is a useful separate control because the user is reloaded.

**Evidence:** [password changes](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/application/AuthService.java:333), [token lifetime and validation](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/security/JwtProvider.java:23), [user resolution](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/security/CustomUserDetailsService.java:44).

**Action and check:** Add a revocation/session-version design, shorter access lifetimes and an explicit session lifecycle. Issue a token, reset the account password separately, and verify the old token is rejected immediately under the chosen policy.

### F11 — High — General authentication abuse controls are absent from application code

**Status:** Confirmed repository gap; external protections unverified.

Login has no visible account/IP attempt limit or adaptive delay. Registration, availability and recovery-channel resolution also have no general throttling. OTP issuance has per-user/per-purpose limits, which is good, but these do not protect password guessing, broad enumeration or creating many accounts to drive email/storage costs. Unknown-account login also skips password hashing, creating a potential timing signal.

**Evidence:** [login implementation](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/application/AuthService.java:182), [public endpoints](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/config/SecurityConfig.java:82), [limited OTP scope](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/otp/VerificationService.java:203). See [OWASP authentication guidance](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html) for throttling and generic error handling.

**Action and check:** Apply layered account, source and global limits with careful recovery behavior and monitoring. Confirm any edge limits in deployed configuration. Validate throttling with bounded tests against a disposable environment; do not lock users out indefinitely.

### F12 — Medium — Public recovery and availability endpoints reveal account existence

**Status:** Confirmed, intentional API behavior with privacy consequences.

`recovery/channels` distinguishes unknown accounts with 404 from existing accounts with verified channel metadata. Availability reveals whether email and phone are registered. Thus the generic `forgot-password` response does not provide anti-enumeration across the full recovery flow. Masked destinations still disclose account and channel existence.

**Evidence:** [recovery resolution](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/application/AuthService.java:274), [availability checks](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/application/AuthService.java:69), [controller contract](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/controller/AuthController.java:114).

**Action and check:** Document the tradeoff; consider generic recovery initiation and narrowing sensitive availability checks. Add abuse limits regardless. Compare full responses, status codes and timing for existing versus absent identifiers.

### F13 — Medium — Secure storage silently falls back to plaintext preferences

**Status:** Confirmed behavior; practical impact depends on platform and failure.

Any native secure-storage failure causes `AuthStorage.saveSession()` to persist the JWT in `SharedPreferences`. This is production code, not a test-only fallback. Web uses preferences by design. Privacy copy says session tokens are in secure storage without explaining these exceptions. Sensitive downloaded documents also use predictable temporary filenames and have no explicit sign-out cleanup.

**Evidence:** [fallback writes](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/auth/auth_storage.dart:62), [privacy claim](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/profile/screens/privacy_screen.dart:61), [temporary file handling](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/documents/document_detail_page.dart:62).

**Action and check:** Make insecure persistence an explicit product decision; prefer memory-only sessions or actionable storage failure on supported native platforms. Use per-account temporary paths and cleanup. Simulate secure-store failure and inspect persistence without exposing token values in logs.

### F14 — High — OTP delivery failure can roll back registration despite the catch

**Status:** Strongly inferred from Spring transaction propagation; failure injection required.

`AuthService.register()` and the separate `VerificationService.issue()` are transactional with default propagation. The latter delivers email synchronously and can throw a runtime `VerificationUnavailableException`. Although the caller catches it intending to preserve the account, the transactional interceptor can already mark the shared transaction rollback-only. Registration can then fail at commit rather than returning a usable account. Recovery catches similar exceptions inside a transaction, so its intended generic-success behavior also needs testing.

**Evidence:** [registration catch](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/application/AuthService.java:164), [transactional issuance](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/otp/VerificationService.java:68), [delivery exception](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/otp/SmtpEmailSender.java:43). This mechanism follows Spring's [transaction propagation documentation](https://docs.spring.io/spring-framework/reference/data-access/transaction/declarative/tx-propagation.html).

**Action and check:** Separate durable account/OTP state from provider delivery using an appropriate transaction boundary and retryable delivery/outbox. Inject SMTP failure and verify the resulting HTTP response, account existence, usable resend flow and recovery behavior.

### F15 — High — Read-then-write guards do not serialize concurrent requests

**Status:** Confirmed missing synchronization; exact race outcomes are inferred.

OTP verification reads the latest usable row and then updates attempts/consumption without row locking or an entity version. Parallel verifications can read the same state; isolated transactions preserve sequential attempt counting but do not serialize competing updates. OTP issuance caps/cooldowns also use read-then-write checks. Dose duplicate protection checks existence before insert, without a matching unique database constraint; concurrent requests can create duplicates.

**Evidence:** [OTP verification](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/otp/VerificationService.java:131), [OTP repository](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/otp/VerificationOtpRepository.java:19), [dose duplicate guard](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/medicines/application/DoseService.java:143), [dose constraints](C:/Users/patel/Personal_Data/blistra/backend/src/main/resources/db/migration/V006__Medicines_schema.sql:105).

**Action and check:** Use atomic conditional updates or correctly scoped locking/versioning, and define unique/idempotent dose occurrence semantics. Run controlled simultaneous wrong-code, correct-code, resend and dose-record requests; assert bounded attempts, one successful consumption and one intended record.

### F16 — Medium — Database and file operations have commit-time failure windows

**Status:** Confirmed ordering; failure consequences inferred.

Document upload compensates errors thrown by `save()`, but errors can occur later when the surrounding transaction flushes/commits. Deletion removes the physical file before database commit; a later rollback can restore metadata for missing bytes. Photo replacement similarly deletes the previous file before commit. Comments describing these paths as safe do not cover every transaction outcome.

**Evidence:** [document upload](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/documents/application/DocumentService.java:130), [document deletion](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/documents/application/DocumentService.java:224), [photo replacement](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/profile/application/ProfileAvatarService.java:77).

**Action and check:** Model storage changes as recoverable lifecycle states, with transaction-aware compensation, post-commit deletion and reconciliation. Inject a commit failure after a successful storage operation and verify there is neither inaccessible metadata nor an untracked orphan left indefinitely.

### F17 — Medium — Account deletion is useful but physical erasure is best-effort

**Status:** Confirmed implementation limitations; external retention policy unverified.

Deletion requires the password, removes personal tables, preserves shared finance history and anonymizes the account where necessary. Those are meaningful strengths. File deletion after commit, however, only logs failures; no durable retry/reconciliation was found. Shared expense descriptions/notes and settlement notes remain, and may contain personal information even after identity fields are anonymized. Downloaded local copies and scheduled notifications also require device cleanup.

**Evidence:** [deletion service](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/profile/application/AccountDeletionService.java:69), [file purge failure path](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/profile/application/AccountDeletionService.java:133), [user-facing deletion wording](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/profile/screens/privacy_screen.dart:99).

**Action and check:** Define retained/shared fields, backup expiry and physical-file deletion guarantees, and add durable cleanup retries. Test deletion with shared and unshared history plus failed storage deletion. Inspect all tables and storage, not only whether login stops working.

### F18 — Medium — Saved timezone and region preferences do not consistently drive behavior

**Status:** Confirmed inconsistency.

Profile updates store a timezone, but backend `UserTime` uses one configured global zone. Several frontend requests pass the device's current numeric offset, which can disagree with the profile and does not identify future DST rules. The region screen states that the profile timezone defines “today.” Device timezone inference also has incorrect mappings, such as offset +180 minutes to Dubai and -660 to Honolulu, and cannot generally infer an IANA zone from offset alone.

**Evidence:** [global zone](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/common/time/UserTime.java:38), [stored timezone](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/profile/application/ProfileService.java:81), [region promise](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/profile/screens/region_screen.dart:27), [offset mappings](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/device/device_context.dart:91), [request offsets](C:/Users/patel/Personal_Data/blistra/frontend/lib/app/app_dependencies.dart:113).

**Action and check:** Resolve a per-user IANA timezone consistently and obtain device zone identity from a reliable platform source. Test near midnight with profile/device zones differing, travel, and DST transitions. Verify habits, meals, medicines, finance months and Planner agree.

### F19 — Medium — Money display hides precision that the ledger preserves

**Status:** Confirmed deterministic discrepancy.

Storage and calculations correctly preserve four decimals. `Money.display()` cuts the fraction to two decimals rather than applying an explicit currency-aware display policy. For example, `1.9999` displays as `1.99`, and `0.0001` displays as zero. The split calculator intentionally preserves sub-cent remainders, so hidden balances can be real. Supported currencies also include JPY, while splitting uses cents generally.

**Evidence:** [display truncation](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/money/money.dart:133), [split remainder](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/finance/application/SplitCalculator.java:103), [settlement display](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/finance/screens/friend_detail_screen.dart:257).

**Action and check:** Define accepted precision, rounding and settlement behavior by currency. Show exact values when they affect reconciliation. Test sub-cent balances, `1.9999`, negative values and zero-decimal currencies end to end.

### F20 — Medium — Shared finance changes lack an auditable agreement model

**Status:** Confirmed product/design limitation.

Accepted friendship protects strangers from being added to new expenses, and only the creator edits/deletes an expense. Nevertheless, the creator can change or remove another person's balance history, and either party can record a settlement in either direction without counterpart confirmation. No immutable change history, dispute state or participant notification was found. Concurrent edits also have no version check.

**Evidence:** [expense mutation](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/finance/application/ExpenseService.java:77), [settlement recording](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/finance/application/SettlementService.java:68), [friend acceptance](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/finance/application/FriendService.java:132).

**Action and check:** Decide whether this is a personal record or a mutually agreed ledger. Add change history and clear “recorded by” wording; consider participant notification/confirmation where appropriate. Test edited/deleted expenses after settlement, concurrent edits, unfriending and deleted counterpart accounts. Do not represent a recorded settlement as proof of payment.

### F21 — Medium — Users cannot open the policies they are asked to accept

**Status:** Confirmed UI and API gap.

The registration Terms/Privacy Policy labels are styled text spans without link actions. The API allows `termsAccepted` to be absent for legacy clients because the field is nullable, and records only an acceptance timestamp without a policy version. A meaningful consent record and understandable disclosure cannot be inferred from this checkbox alone.

**Evidence:** [policy text](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/auth/auth_screen.dart:2423), [nullable acceptance](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/dto/RegisterRequest.java:51), [timestamp storage](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/auth/application/AuthService.java:149).

**Action and check:** Publish readable policies, make them accessible before acceptance, define compatibility behavior for old clients, and record the accepted policy version. Determine jurisdiction-specific requirements with appropriate expertise before launch; this review makes no compliance determination.

### F22 — High — APK publishing permits debug signing and mixes release audiences

**Status:** Confirmed workflow behavior; actual secret availability unverified.

The workflow explicitly builds with a debug key if keystore secrets are absent, and Gradle selects debug signing without `key.properties`. Such artifacts are still published as GitHub releases. Debug keys may differ across build machines, preventing installed users from upgrading in place. Pushes to both `develop` and `main` use the same release mechanism; the app update source selects non-prerelease APK releases, so development builds can enter the same update channel.

**Evidence:** [workflow fallback](C:/Users/patel/Personal_Data/blistra/.github/workflows/android-apk.yml:33), [Gradle signing](C:/Users/patel/Personal_Data/blistra/frontend/android/app/build.gradle.kts:34), [release triggers](C:/Users/patel/Personal_Data/blistra/.github/workflows/android-apk.yml:6), [update source](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/appupdate/application/GitHubReleaseSource.java:69). Android documents signing and key continuity in its [app-signing guide](https://developer.android.com/studio/publish/app-signing).

**Action and check:** Fail production publishing when signing is missing, verify the certificate fingerprint, and define distinct test/production channels. Pin release toolchain/action versions appropriately. Install N and update to N+1 on a device with the same signing identity; verify develop builds are not offered to production users.

### F23 — High — Available tests are not enforced as release gates

**Status:** Confirmed repository automation gap; hosted branch protections unverified.

The only discovered workflow runs four frontend test files, builds an ARM64 APK and publishes it. It does not run the full frontend suite/analyzer or backend integration tests. The Docker build skips tests and Render auto-deploys. Existing backend reports are encouraging, but they do not gate new releases or demonstrate reminder delivery, file persistence or the full Documents journey.

**Evidence:** [workflow tests](C:/Users/patel/Personal_Data/blistra/.github/workflows/android-apk.yml:50), [test-skipping image build](C:/Users/patel/Personal_Data/blistra/backend/Dockerfile:8), [automatic deployment](C:/Users/patel/Personal_Data/blistra/render.yaml:11), [opt-in live contract suite](C:/Users/patel/Personal_Data/blistra/frontend/test/e2e/contract_test.dart:1).

**Action and check:** Gate release/deployment on analyzer, relevant full unit/widget suites, PostgreSQL integration tests and a disposable-environment contract smoke test. Add real-device release-build checks for notifications, file open and upgrade. Confirm required checks in hosting settings rather than assuming them.

### F24 — Medium — Missing release configuration can produce an unusable APK

**Status:** Confirmed default behavior.

If the workflow's `API_BASE_URL` variable is empty, `AppConfig` falls back to the Android emulator host `http://10.0.2.2:8080`. A physical-device APK can therefore build and publish successfully while pointing at an unusable development address. Arbitrary supplied URLs also lack a release-mode HTTPS/scheme/host validation step. Android transport policy may block some HTTP traffic, which is an availability symptom rather than a configuration check.

**Evidence:** [URL fallback](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/config/app_config.dart:41), [workflow URL input](C:/Users/patel/Personal_Data/blistra/.github/workflows/android-apk.yml:54).

**Action and check:** Validate required production inputs and HTTPS before build/publish. Verify the release artifact's effective environment and perform a bounded health/auth smoke check against the intended service.

### F25 — Medium — Health checks and observability do not demonstrate feature readiness

**Status:** Confirmed code/configuration gap; external monitoring unverified.

Render checks `/health`, which always returns `UP` without checking the database or storage. Dashboard adapters catch exceptions and return unavailable sections, often without logging the underlying event. This helps UI resilience but can hide widespread module failures from operators. No durable security-event audit stream, alert configuration, backup/restore runbook or deletion-retry worker was found in the reviewed deployment path.

**Evidence:** [constant health](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/common/controller/HealthController.java:22), [Render probe](C:/Users/patel/Personal_Data/blistra/render.yaml:10), [suppressed module failure](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/dashboard/application/HealthSummaryProvider.java:55), [dashboard aggregation](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/dashboard/application/DashboardService.java:97).

**Action and check:** Separate liveness/readiness, emit sanitized per-module errors/metrics, and establish alerting and recovery ownership. Simulate database unavailability and missing document storage; verify operators detect the problem and a restore drill recovers both metadata and files.

### F26 — Medium — Platform and localization promises exceed verified implementation

**Status:** Confirmed implementation gaps; complete platform behavior untested.

Local-notification initialization contains Android settings only. Document opening uses `dart:io`, temporary filesystem paths and an external file opener without a web-specific flow. The app stores a language preference but `MaterialApp` has no locale/delegate wiring and user-facing strings remain English. The iOS display name is still `Frontend`. Generated platform folders do not establish feature parity.

**Evidence:** [notification initialization](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/notifications/services/flutter_notification_scheduler.dart:39), [document opening](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/documents/document_detail_page.dart:56), [app localization setup](C:/Users/patel/Personal_Data/blistra/frontend/lib/app/app.dart:79), [language preference](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/profile/screens/region_screen.dart:64), [iOS identity](C:/Users/patel/Personal_Data/blistra/frontend/ios/Runner/Info.plist:8).

**Action and check:** Publish an explicit supported-platform matrix. Hide unsupported controls or supply platform implementations. Validate iOS and web separately, and do not imply that storing a language/units preference guarantees every screen has applied it.

### F27 — Medium — Upload protection lacks aggregate limits and full content handling

**Status:** Confirmed repository gap; external scanning/encryption unverified.

Documents have good size caps, magic-byte checks, server-generated keys and owner-only downloads. These do not cap a user's total storage or request rate, or prove a PDF/image is safe to open. No aggregate quota, malware scanning/quarantine, image dimension/decode limits or content normalization was found. A user can fill disk with many individually valid files; unverified-account access compounds this exposure.

**Evidence:** [file validation](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/documents/application/DocumentValidator.java:32), [bounded filesystem writes](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/documents/storage/LocalFileSystemDocumentStorage.java:43), [upload service](C:/Users/patel/Personal_Data/blistra/backend/src/main/java/com/blistra/documents/application/DocumentService.java:76).

**Action and check:** Define per-account/global storage and rate budgets, quarantine/scanning policy, image handling limits, and storage encryption/access expectations. Test many allowed uploads and malformed high-dimension images in isolation. No malicious-file exploit was attempted or established here.

### F28 — Medium — Documentation, support and dependency verification need a release pass

**Status:** Confirmed repository discrepancies; runtime compatibility is unverified.

The README describes a foundation-stage product and several implemented modules as future work. Support email defaults to empty, and the APK workflow does not supply it, so the “Report a problem” path can merely copy diagnostics without providing a destination. The Maven file combines Spring Boot 4.1.1 with springdoc 2.1.0, while springdoc's [current compatibility guidance](https://springdoc.org/#what-is-the-compatibility-matrix-of-springdoc-openapi-with-spring-boot) pairs Boot 4 with springdoc 3.x. This is a compatibility risk, not proof of a newly reproduced startup failure or a CVE.

**Evidence:** [project status](C:/Users/patel/Personal_Data/blistra/README.md:24), [support default](C:/Users/patel/Personal_Data/blistra/frontend/lib/core/config/app_config.dart:39), [help behavior](C:/Users/patel/Personal_Data/blistra/frontend/lib/features/profile/screens/help_screen.dart:116), [dependency declaration](C:/Users/patel/Personal_Data/blistra/backend/pom.xml:100).

**Action and check:** Publish an accurate implemented/experimental roadmap, wire a monitored support contact, align dependencies against their actual compatibility matrices, and test production startup plus `/v3/api-docs`. Generate a dependency inventory and scan resolved backend/mobile dependencies before release; no comprehensive dependency audit was performed here.

## 6. Security and privacy assessment across trust boundaries

| Boundary/threat | Controls observed | Remaining work |
|---|---|---|
| Anonymous caller to API | Mostly authenticated endpoints; BCrypt passwords; generic login messages | Login/registration abuse controls, enumeration policy, verified-account permissions. |
| Authenticated user to another user's records | Frequent owner-scoped queries, 404 for inaccessible resources; shared-finance participant rules | Systematic endpoint ownership matrix and tests for every new endpoint/filter/child relationship. |
| Stolen bearer token to account | Signature/expiry validation; minimum secret length; blocked-user lookup | Revocation after recovery, session/device management, stronger storage failure behavior. |
| User file to server/client | File-size caps, limited detected types, UUID storage keys, path normalization, attachment/no-store download headers | Quotas, quarantine/scanning policy, durable storage, lifecycle reconciliation, local cleanup. |
| Backend to email provider | Masked log destinations; production OTP hashing/pepper; short-lived codes | Delivery outside the main request transaction, retries, concurrency protection, global spend limits. |
| Backend reminder to OS | User notification preferences, deterministic IDs, local scheduling | Delivery receivers, medicine integration, offline cleanup, device lifecycle and timing validation. |
| CI/source to installed app | Keystore secret support, HTTPS GitHub downloads, Android installer confirmation | Fail-closed release signing, channel separation, complete tests and provenance. |
| Operator/storage access | Non-root container, environment-based production secrets | Verify least privilege, encryption, backup access, audit events, retention and incident response in hosting. |

Important distinctions:

- Disabling CSRF is consistent with the inspected stateless bearer-header API; this alone was not classified as a vulnerability.
- Wildcard CORS in `render.yaml` is broader than needed for a future web deployment, but does not by itself reveal authenticated records. The inspected CORS setup does not enable credentialed cookie requests. Restrict browser origins when deployment requires it.
- Public Swagger is not inherently a sensitive-data breach. Decide whether production needs it, and test its dependency compatibility.
- Parameterized SQL and whitelisted search modules are positive. No SQL-injection finding is asserted from string-built fixed SQL fragments.
- Development OTP access is gated by the dev-mode property, and production defaults it off. Still add deployment assertions against accidentally enabling development mode or using known development keys.
- A private vault is not end-to-end encryption. No evidence establishes that server operators cannot read stored bytes; user-facing privacy language should reflect the actual model.
- Centralizing health, financial, document and identity data increases the impact of one account compromise. Treat recovery and device/session cleanup as central product features.

### Data lifecycle and governance

| Data | Current lifecycle evidence | Governance decision/check |
|---|---|---|
| Account/profile | Identity verification, staged identity changes, password-confirmed deletion | Minimize mandatory profile fields; define age policy, terms versions and access procedures. |
| Health/medicines/diet | User-owned records and histories | Define export, correction, retention and safety wording; distinguish manual data from measurements. |
| Finance | Exact values, personal and shared records, retained shared history on deletion | Define participant rights, edits, dispute handling, and retained free text. |
| Documents/photos | Private API access; filesystem bytes separate from DB metadata | Durable storage, quota, restore consistency, scanning and erasure completion. |
| OTPs | Hashed production codes, expiry and counters | Delete old OTP records/destinations on a retention schedule and serialize use. |
| Device state | Native secure storage preference, local notifications, downloaded temporary files | Explicit logout/account-switch cleanup; platform backup and cache policy verification. |
| Logs/diagnostics | Generic auth errors, some user IDs and masked destinations | Access restrictions, retention, correlation IDs and sensitive-data exclusion. |

No general user-data export flow was found in the inspected client/API paths. Make portability a deliberate product decision, with a verified export format and access controls. Determine applicable legal requirements from actual markets, users, data practices and business relationships; repository principles alone do not prove compliance.

## 7. Engineering, performance and maintainability

### Architecture

The modular monolith is appropriate to this stage. Domain packages, DTOs, Bean Validation, migrations and PostgreSQL integration tests are better assets to strengthen than replacing the system with microservices.

There is some drift from the documented boundaries: dashboard adapters read other domains' repositories directly, and unified search/deletion embed cross-domain schema knowledge. This is manageable in one codebase but needs explicit ownership and migration tests. Define stable read interfaces and a deletion inventory so schema changes cannot silently break aggregation or erasure.

The frontend has both current and legacy authentication/notification/dependency paths. F08 shows the practical risk: a correct cleanup operation exists in the older path but is absent from the active one. Consolidate ownership incrementally after behavior is covered, rather than doing a large structural rewrite first.

### Performance and resilience

The following are code-based hypotheses to measure, not measured bottlenecks:

- Home aggregates multiple domains synchronously. Health summary queries once per measurement type; search runs a count plus a multi-branch union page query using leading-wildcard text matching. With a production connection pool default of five, concurrent Home/search requests can become expensive.
- Existing indexes support ownership/date access, but no full-text/trigram search index was found in migrations. Measure representative query plans before selecting an index strategy.
- All reminder history is fetched and cancelled/re-scheduled during refresh. Long-lived accounts can accumulate work; device scheduling limits and API payload growth need a bounded horizon and retention strategy.
- Several feature pages are kept alive through `IndexedStack`; this preserves state but can trigger offscreen initialization and requests for mounted tabs. Measure initial request count and memory on a modest Android device.
- The client permits a 110-second request timeout and performs a warm-up call for a sleeping backend. This is understandable for a test deployment, but the user needs clear progress, retry and offline behavior. Hosting latency remains a product cost.
- Profile timezone changes and returning from background do not have an evident app-wide refresh/reconciliation mechanism. Test an app left open overnight and edits made on a second device.
- Uploads/downloads are buffered in memory on the client. Current size caps limit individual cost, but file selection reads bytes before the UI validates size; verify low-memory behavior.
- Missing-data and unavailable sections are generally distinguishable in dashboard code, which is positive. Preserve that distinction in every derived total and chart.

### Supply chain and deployment

The multi-stage Docker build and non-root runtime are good. Establish reproducible Flutter/JDK versions, a resolved dependency inventory, automated vulnerability/license checks and controlled release promotion. Floating action tags, unpinned Flutter stable and broad dependency declarations such as `http_parser: any` increase reproducibility uncertainty even where lockfiles help.

Confirm the final image actually contains the command used in Docker's `HEALTHCHECK` (`wget`); the Dockerfile does not install it. This was not executed, so it is a verification item, not a confirmed broken image. Similarly verify database TLS, SMTP TLS requirements, secrets access, backup retention and least-privilege database roles in the actual deployment.

## 8. Domain-specific assessment

| Module | Strengths | Priority beyond the findings |
|---|---|---|
| Dashboard | Cross-domain summary, unavailable-section handling, shared quick actions | Explain freshness; align date semantics; monitor partial failures and request cost. |
| Planner | Explicit task states, lists/events, task reminder reconciliation | Test completed/reopened/rescheduled tasks across devices, timezone changes and offline retries. |
| Health | Owner-scoped records, measurement validation, informational summary wording | Device accessibility, stale/missing measurement visibility, export and correction ergonomics. |
| Medicines | Explicit dose events, parent ownership, archive/history, scheduled-slot matching | Reliable alert integration; race-safe dose identity; review early-dose recording constraints with product requirements. |
| Diet/water | Canonical water units, item-level nutrition, arithmetic summaries | Fast repeat meals, distinguish partial nutrition from complete totals, consistent date boundaries. |
| Habits | Type-specific targets, schedules, completion/streak logic, batched today lookup | Per-user timezone, schedule edits/history semantics, avoid punitive messaging for incomplete data. |
| Finance | Exact arithmetic, deterministic splitting, accepted friendships, currency-separated balances | Visible precision, audit trail, dispute model, participant communication and conflict handling. |
| Documents | File validation, private downloads, metadata pagination, sanitized filenames | Durability and complete successful/failure client journeys before adding features. |
| Reminders | Central model, preferences, deterministic device IDs, no startup permission prompt | Device delivery tests, logout cleanup, recurrence, tap routing and multi-device reconciliation. |
| Profile/settings | Identity confirmation, account deletion, privacy switch, emergency contact | Ensure language/timezone/units settings actually apply; accurate privacy copy and accessible policies. |
| Search | Bound parameters, server-side ownership filters, deterministic pagination | Performance on realistic histories and correct route/detail resolution for every result type. |
| Goals/AI | Bounded-assistance intent documented | Treat as future scope; no production AI capability was established in this review. |

Medical functionality should remain recordkeeping and support. Avoid inferring health status from absent records, and clearly explain reminder limitations. The code generally avoids diagnostic interpretations; preserve that boundary as summaries become richer.

## 9. Prioritized action plan

This is a recommended sequence, not authorization to change the application and not an effort estimate.

| Phase | Work | Suggested owner | Exit condition |
|---|---|---|---|
| 1 — Protect data and complete core journeys | F01–F04, F06–F10 | Backend + Flutter + deployment | Durable files; working document open/upload failure paths; onboarding completes; reminders and session cleanup verified. |
| 2 — Close security/correctness gaps | F05, F11–F18, F21, F27 | Backend/security + Flutter | Account-state policy, bounded abuse, atomic OTP use, revocation, storage lifecycle/erasure and timezone tests pass. |
| 3 — Make releases reviewable and recoverable | F22–F25, F28 | Release/operations | Stable signing, required checks, environment validation, readiness, support contact and restore drill. |
| 4 — Refine product quality | F19–F20, F26, accessibility, performance, product metrics | Product/design + engineering | Exact balances understandable; supported platforms declared; pilot journeys measured and reliable. |

Resolve supporting controls in the same release when phases depend on each other. For example, a reminder feature is not ready merely because medicine reminder rows exist if the Android receiver is still absent.

## 10. Release acceptance checklist

- [ ] Upload documents/photos, restart and redeploy, and retrieve original bytes.
- [ ] Preview an image and open a PDF from the production app provider graph and search route.
- [ ] Failed upload leaves the form usable, preserves input and never returns success.
- [ ] Registration with/without phone works under the actual email/SMS capabilities.
- [ ] Define and test API permissions for unverified/pending accounts.
- [ ] Reset/change password invalidates tokens according to a documented policy.
- [ ] Login, registration, recovery and availability have verified abuse limits.
- [ ] Simultaneous OTP requests cannot bypass attempt/consumption guarantees.
- [ ] Duplicate/retried dose and finance writes have defined, tested semantics.
- [ ] General, task and any advertised medicine reminders deliver in a release build while backgrounded and after reboot.
- [ ] Logout, expiry, deletion and account switching clear notifications, routes and previous-account state even offline.
- [ ] Profile/device timezone disagreement and DST tests produce consistent daily views.
- [ ] Shared expense edits and settlements explain who changed balances; precision is visible.
- [ ] Account deletion removes personal records, tracks failed file purges and accurately describes retained shared data.
- [ ] Policies can be read before acceptance; terms version and required acceptance are recorded.
- [ ] Production build fails without signing and endpoint configuration; upgrade continuity is demonstrated.
- [ ] Required frontend/backend checks pass on the release commit, with fresh results.
- [ ] Supported platform/device/accessibility matrix is tested and published.
- [ ] Operators detect dependency/module failure and successfully restore database plus file storage.
- [ ] Every release offers a working support contact and contains no unsupported privacy/delivery claims.

## 11. Remaining evidence needed

Before a final launch decision, obtain a disposable test environment, release APK/device access, current deployment configuration, backup/restore evidence, CI/branch protection settings and user-research results. A follow-up review should focus on reproducing the inferred concurrency/transaction/session cases, then validate remedies on the exact release build.

Do not treat historical green tests, design images, security principles or generated platform folders as substitutes for these checks.

## 12. Change-preservation record

- Initial Git status showed only existing untracked `.claude/` content; no tracked changes were reported.
- A SHA-256 baseline of all 933 tracked files was captured during read-only inspection.
- The only file created by this review is `APPLICATION_REVIEW_2026-10-17.md`.
- Final verification compared all 933 tracked files against the SHA-256 baseline: **zero changed tracked files**. `git diff --stat` was empty.
- Final Git status showed only the pre-existing untracked `.claude/` directory and this new report. All 97 local evidence links resolved to existing files.
