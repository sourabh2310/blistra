# Application review remediation

Updated: 2026-10-17. Source: `APPLICATION_REVIEW_2026-10-17.md` (preserved as the original review).

The user authorized implementation after the initial read-only review, required the other participant to confirm settlements, and requested multi-person trip groups. Changes are local; no production deployment, hosting purchase, release publication, or database migration against live data has been performed.

## Implemented product behavior

- Finance → Groups: create named groups, invite by exact username, accept/decline invitations, view accepted members, and transfer ownership before leaving. Up to 100 members per group. Owners control invitations; invitees cannot read the ledger until they join.
- Add a group expense shared by multiple accepted members using equal, exact, percentage, or weighted splits. Multiple groups can contain different or overlapping people. Friend-only balances and each group's balances stay separate; currencies are never converted or netted against another currency.
- Dashboard/Overview spending includes your trip shares. Outstanding friend-balance summaries are separate from trip positions, which are shown inside Groups.
- A payment is initially **pending**. Only the other payer/payee can confirm or reject it; group membership alone does not grant that permission. Pending/rejected payments have no balance effect. Confirmation retries are idempotent. Confirmed payments cannot be silently deleted; corrections require another payment and confirmation.
- Payments from before this update retain their original balance effect under **LEGACY_RECORDED**, which does not claim that another participant confirmed them.
- Changes to expenses and payments produce an application change history with actor, action, timestamp and amount. Notes and descriptions are excluded from the history. This is application history, not a bank receipt or a tamper-proof external audit. Historical changes before the migration cannot be reconstructed.
- Removing membership preserves past shared records and balances. Owners must transfer ownership before leaving. Account deletion transfers ownership to an accepted member when one exists, and anonymizes identities needed by shared finance records.

## Finding-by-finding status

“Implemented” describes local code, not evidence of a deployed production fix. “Partial” identifies remaining engineering or operational work.

| Finding | Status | Changes and remaining work |
|---|---|---|
| F01 Durable file storage | Partial; rollout required | Render blueprint mounts a persistent volume; container refuses a missing volume and runs Java without root privileges. Copy existing files before replacing the old service. Volume + database backup/restore drill remains required. |
| F02 Document preview provider | Implemented | Detail uses the DocumentsProvider registered by the app, including download/open. Device file-opening validation remains. |
| F03 Failed upload shown as success | Implemented | Null/failed upload retains the form and selected file and displays an error. |
| F04 Optional phone onboarding | Implemented | Backend requires phone verification only when SMS is configured; frontend defaults to email verification. Configure both together if SMS is enabled. |
| F05 Pending account access | Implemented policy | Production requires verified email before finance mutations, document uploads/mutations, and avatar uploads. Personal non-sharing features remain available. Development intentionally relaxes this policy. |
| F06 Android receivers | Implemented; device validation pending | Scheduled and boot receivers declared. Verify real-device notification delivery after process death/reboot and permission denial. |
| F07 Medicine reminders | Implemented with limits | Seven-day server projection, resynced after medicine changes/resume; next 60 notifications scheduled. Settings disclose this rolling horizon. Long-term offline/background renewal is not implemented. |
| F08 Notification cleanup | Implemented | Logout/expiry cancels OS notifications offline, invalidates pending refreshes and serializes scheduler operations. |
| F09 Account isolation | Implemented | Replaces session-owned feature controllers, resets navigator, clears app-owned preview cache, and rejects late API responses from another token. Regression coverage added. |
| F10 Token revocation | Implemented | Session-version claim checked against current user; password change/reset increments version. Password change signs the client out. Login tokens have unique IDs. |
| F11 Auth abuse | Partial | Persistent source and per-account login limits plus existing OTP budgets. Review trusted proxy/IP handling before launch, add edge/global capacity controls and monitor actual traffic. |
| F12 Discovery privacy | Partial | Production availability checks no longer disclose email/phone registration; recovery channels are generic. Explicit registration conflicts still disclose duplicates under rate limiting. Further reducing registration/timing disclosure requires a revised onboarding flow. |
| F13 Plaintext credentials | Implemented | Removes legacy plaintext preferences; secure-storage failure keeps an in-memory session. A non-secret logout marker prevents restoring a secure token after failed erasure. |
| F14 OTP delivery/transactions | Partial | Mail outage no longer rolls registration back or leaves an undelivered code blocking retry. A transactional outbox/delivery worker is still needed for delivery across process crashes or DB commit failure after mail delivery. |
| F15 Concurrent writes | Partial | Locks OTP issuance/consumption, dose recording, upload quota checks, expense edits and settlement decisions. New concurrency regression proves single-use OTP. Broader concurrent financial/account lifecycle load testing remains. |
| F16 Storage commit windows | Implemented and integration-tested | Rollback removes new uploads; deletion waits for commit; durable retry queue survives failures. Filesystem upload markers reconcile interrupted uploads after a 24-hour grace period. Cleanup avoids borrowing a second connection while the upload transaction holds one. |
| F17 Physical erasure | Partial | Durable deletion retries and orphan reconciliation; personal history removed; shared records anonymized and disclosed. Define backup retention, operator access and deletion service levels, and verify provider behavior. |
| F18 Timezone semantics | Partial | Authenticated profile IANA zone now drives backend date boundaries/planner/medicine calculations, with DST regression coverage. Onboarding exposes the suggested zone for confirmation. Device offset inference remains an estimate; full native IANA detection and travel tests remain. |
| F19 Money precision | Implemented | Displays exact sub-cent debt instead of making it appear zero; finance entry accepts up to four decimal places so those debts can be settled. Regression tests include positive/negative fractions and carry boundaries. |
| F20 Shared finance agreement | Implemented core; enhancements remain | Two-party settlement decisions, group consent and application change history added. Full before/after split snapshots, participant dispute/edit approvals, archival/export and external audit integrity remain future work. Expenses themselves remain creator-editable; payment confirmation is not expense approval. |
| F21 Policies/consent | Partial | Readable linked Terms/Privacy screens with a version; production registration enforces consent and records policy version. Owner/legal review, operator identity, jurisdiction and final retention promises remain required before public launch. |
| F22 Signing/release channel | Implemented configuration | Release signing fails without the real key. APK publication only from main; develop/PRs run verification. No key generated or live release published. Configure repository protections externally. |
| F23 CI gates | Implemented configuration; CI execution pending | Backend verify, Flutter analyzer/tests, and disposable API/Flutter contract tests gate the APK job. Branch protection and a successful hosted CI run still need verification. |
| F24 Release environment | Implemented | Release requires an explicit HTTPS API origin; CI validates origin and requires support email. No production URL/inbox has been invented. |
| F25 Readiness/observability | Partial | Database, disk and writable document-volume readiness gates deployment. Alerting, error-rate/latency dashboards, deletion backlog monitoring and an incident drill remain. |
| F26 Platform/localization | Partial | iOS display name corrected, Apple notification permissions wired, unsupported-platform permission result explicit. UI discloses English/metric limitations and removes unimplemented choices. Android is the current release target; other platform builds/device tests remain. |
| F27 Upload controls | Partial | Per-user 100-file / 100-MiB quotas serialized with uploads; 10-MiB per-document limit retained. Malware scanning, robust PDF/image decoding, global storage budgeting and image downsampling remain. MIME/signature checks do not provide antivirus protection. |
| F28 Documentation/support/dependencies | Partial | README/deployment guidance and this tracker updated; Springdoc updated for the current Spring Boot generation. CI requires a real support address. Full dependency advisories/SBOM review and support runbook ownership remain. |

## Validation record

- Final backend gate: `mvnw verify` — **565 tests across 69 suites passed**, zero failures, errors or skips. This includes three-person group sharing, access denials, cross-trip isolation, settlement decisions, historical payments, group ownership/account deletion, password change/recovery revocation, optional-phone onboarding, delivery failure/retry, preservation of the last delivered OTP, concurrent OTP consumption, abuse limits, storage rollback/reconciliation and profile-zone DST behavior.
- Final Flutter regression suite: **338 passed**, including group screens, invitation consent, confirmation dialog, exact payment entry, logout/controller/route isolation, stale responses and credential-storage failures.
- Flutter analyzer: **no errors**, with **22 existing lint warnings/notices** remaining. CI fails on analyzer errors; the residual lint debt is not treated as a clean analyzer result.
- Real Flutter clients against a disposable local PostgreSQL/backend: **9 contract tests passed**, covering planner, diet, habits, health, medicines, direct shared finance, trip groups, documents and dashboard/preferences/search.
- Storage follow-up after the full backend gate: **3 integration tests passed**, including retaining bytes after an ambiguous commit result until reconciliation can inspect metadata. Upload rollback, post-commit deletion and interrupted-upload cleanup also pass. Temporary contract services were stopped after verification.
- Final backend package builds successfully. Workflow/deployment YAML, Python bootstrap syntax, Android manifest, iOS plist, Linux script line endings and Git whitespace checks passed.
- Focused frontend screen checks after the final group-form copy/default adjustment: **8 passed**.
- Physical device reboot/notification timing, signed APK installation/update, provider backup restore, hosted CI and actual production migration have not been validated.

## Release sequence and remaining decisions

1. Review the recorded verification results, complete diff and migrations V109–V114.
2. Review the costed persistent-storage blueprint. Preserve existing files and create a matched database/file backup before any restart or deployment. Follow `docs/deployment.md`.
3. Configure production mail, support contact, exact browser CORS origins, JWT/OTP secrets and stable signing secrets. Test proxy rate limits under the actual hosting topology.
4. Owner approves policies, operational retention/access rules and incident/support responsibilities. Do not assert a compliance certification from these code changes.
5. Run a small Android pilot with at least three people, two overlapping trip groups, multiple currencies, rejected/confirmed payments, travel timezone changes, logout/account switching, and reboot/permission-denied reminder scenarios.
6. Prioritize remaining engineering work using pilot evidence. Suggested measures: verified onboarding completion, first successful shared expense, invitation acceptance, disputed/rejected payment rate, notification delivery misses, upload failures and restore success. Collect only consented/necessary data; no third-party analytics has been added.

## Cross-cutting follow-up from the review

- Product/business: choose one pilot audience and its primary job, validate invitation and repayment behavior with that audience, and establish support ownership. Model cost per active user using database, file retention, SMTP and support demand before promising a free or paid plan. No pricing or revenue claim has been invented.
- Usability/accessibility: test the complete registration → verification → first useful record journey, 200% text scaling, TalkBack navigation, contrast, keyboard focus, empty states, slow/offline errors and destructive actions on actual phones. Automated widget coverage is useful but does not replace these checks.
- Performance: measure dashboard and seven-day reminder query volume, finance pagination, large group rendering, upload memory and startup on the intended host. Establish latency/capacity budgets from measurements and run concurrent login/OTP/upload/account-deletion tests with the production pool size. OTP's existing independent verification transaction still needs explicit pool-saturation testing.
- Trip lifecycle: add full expense before/after snapshots, export/archive and complete history/payment pagination if the pilot needs them. The current UI identifies the latest-100 change-history and latest-200 payment limits. Members who leave need a new invitation to use that group's ledger again; records and balances remain.
- Supply chain/operations: complete advisory/SBOM and immutable CI-action reference review, verify stable signing ownership, run staged migration/restore and incident exercises, then enable repository-required checks and production alerts.
