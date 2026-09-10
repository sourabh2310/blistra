You are working on the Blistra backend.

BRANCH:
stabilization/integration-pass

IMPORTANT CONTEXT:
A prior engineering review has already been performed on this repository.
DO NOT perform a full-repository discovery/audit first.
DO NOT spend tokens explaining the architecture back to me.

Instead, work from the known stabilization issues below and inspect ONLY:
- the named files
- their directly related classes
- their directly related repositories/DTOs/controllers
- their existing tests
- the specific Flyway migrations needed for the database changes

This is a STABILIZATION / HARDENING pass.

============================================================
ABSOLUTE RULES
============================================================

1. NO new product features.

Do NOT implement:
- UPI
- SMS reading
- SMS parsing
- automatic expense creation
- frontend features
- AI features
- push-provider integration
- FCM
- APNs
- new modules

2. Do NOT redesign the architecture.

Keep the existing modular-monolith architecture.

3. Do NOT perform broad refactors.

Make minimal, targeted production-quality changes.

4. Do NOT weaken tests.

Never:
- delete tests
- skip tests
- disable tests
- add @Disabled just to pass
- replace integration tests with mocks
- replace PostgreSQL with H2
- remove Testcontainers
- use -DskipTests for final verification

5. Do NOT blindly modify unrelated files.

6. Do NOT renumber existing Flyway migrations.

7. Before changing a behavior that could be a product decision, inspect the directly related existing code/tests and STOP + REPORT if the correct behavior cannot be determined safely.

8. Preserve existing API contracts wherever possible.

9. Security and privacy take priority over convenience.

10. Do not log:
- passwords
- JWTs
- authorization headers
- push tokens
- document contents
- unnecessary health information
- user email addresses unless there is an existing justified operational need

============================================================
PHASE 0 — VERY SMALL BASELINE
============================================================

Do NOT inspect the whole repository.

Only inspect:

- backend/pom.xml
- backend/src/test/java/com/blistra/AbstractIntegrationTest.java
- backend/src/main/java/com/blistra/common/error/GlobalExceptionHandler.java

Then run:

.\mvnw.cmd test

Record the actual result.

If Testcontainers fails before tests execute, do not weaken anything.
Continue with code stabilization and report the infrastructure problem separately.

============================================================
PHASE 1 — ERROR RESPONSE SECURITY
============================================================

PRIMARY FILE:

backend/src/main/java/com/blistra/common/error/GlobalExceptionHandler.java

RELATED:
- ApiErrorResponse
- directly related exception classes
- existing error/controller tests only

KNOWN ISSUE:

Some handlers expose exception messages directly, for example:

ex.getMessage()

This can expose implementation details to clients.

GOAL:

Client responses must contain safe, stable API-facing messages.

Detailed exception information may remain available to server-side logs.

DO NOT expose:
- SQL errors
- database table names
- Hibernate internals
- Java exception class details
- filesystem paths
- stack traces
- internal implementation details
- secrets

IMPLEMENTATION:

1. Inspect all exception handlers in GlobalExceptionHandler.
2. Identify every place where arbitrary exception text reaches the response.
3. Replace unsafe behavior with safe messages/codes.
4. Preserve useful validation errors where they are genuinely user-facing.
5. Preserve existing ApiErrorResponse structure if possible.
6. Keep HTTP statuses consistent with current API semantics.
7. Unexpected exceptions should return a generic internal-server message.

Add/update focused tests for:
- malformed JSON
- invalid enum
- invalid UUID/path variable
- missing request parameter
- missing multipart parameter where applicable
- validation failure
- resource not found
- expected bad request
- unexpected internal exception

IMPORTANT:
Do not leak the original exception message in the HTTP response.

============================================================
PHASE 2 — PLANNER ALL-DAY TASK SEMANTICS
============================================================

Only inspect directly relevant Planner files, especially:

- PlannerTime
- TaskService
- Task entity
- Task DTOs
- Task controller
- relevant Planner tests

KNOWN ISSUE:

An all-day task has:

dueDate != null
dueTime == null

It must not be treated as a task due at midnight.

BAD MODEL:

all-day task
→ dueDate at 00:00
→ compare with current time
→ becomes overdue immediately after midnight

CORRECT MODEL:

TIMED TASK:
    dueDate + dueTime
    compare using the existing time/instant semantics

ALL-DAY TASK:
    dueDate only
    compare LocalDate against user's current LocalDate

EXPECTED:

all-day due today:
    NOT overdue

all-day due yesterday:
    OVERDUE

all-day due tomorrow:
    NOT overdue

timed due earlier today:
    OVERDUE

timed due later today:
    NOT overdue

DO NOT:
- use noon as a fake due time
- use 23:59 as a fake due time
- use midnight as a fake due time

Preserve the semantic distinction.

Do NOT implement per-user timezone support.

Use the existing UserTime architecture.

Add deterministic tests for:
1. all-day due today
2. all-day due yesterday
3. all-day due tomorrow
4. timed task earlier today
5. timed task later today
6. boundary around midnight
7. configured timezone behavior

============================================================
PHASE 3 — MAVEN CLEANUP
============================================================

Only inspect:

backend/pom.xml

KNOWN ISSUE:

There are duplicate Lombok dependency declarations.

Remove the redundant declaration.

Preserve the valid Lombok configuration.

Do NOT upgrade unrelated dependencies.

Then verify the dependency configuration still compiles.

============================================================
PHASE 4 — TIMESTAMP AUTHORITY
============================================================

Only inspect entities/migrations where the review identified BOTH:

- JPA @PrePersist/@PreUpdate timestamp handling
AND
- PostgreSQL timestamp defaults/triggers

Do not scan every file in the repository unnecessarily.

KNOWN ISSUE:

Some timestamps have two potential sources of truth:

Java/JPA lifecycle callbacks
+
PostgreSQL defaults/triggers

This can cause confusing behavior and clock differences.

GOAL:

One authoritative timestamp strategy.

Preferred direction:
PostgreSQL remains authoritative for created_at / updated_at where the existing schema already uses DB defaults/triggers.

BUT:

Do not blindly convert every entity.

For each affected entity:
1. inspect migration
2. inspect entity mapping
3. inspect existing save/update behavior
4. inspect directly related tests
5. make the smallest consistent correction

Requirements:
- created_at remains populated
- updated_at changes correctly
- no unexpected null values
- entity values remain synchronized after persistence/update
- integration tests verify the behavior

Do not redesign the entire persistence layer.

============================================================
PHASE 5 — FINANCE OWNERSHIP INTEGRITY
============================================================

Only inspect directly relevant Finance files:

- V100__Finance_schema.sql
- Account
- Category
- Transaction
- Transfer
- related repositories
- AccountService
- CategoryService
- TransactionService
- TransferService
- BalanceCalculator
- related DTOs/controllers
- existing Finance tests

KNOWN ISSUE:

Application services already perform ownership checks, but some database relationships do not strongly guarantee:

transaction.user_id
    matches
account.user_id

and:

transaction.user_id
    matches
category.user_id

Likewise:

transfer.user_id
    matches source_account.user_id

transfer.user_id
    matches destination_account.user_id

GOAL:

A financial record must never cross user ownership boundaries.

FIRST:
Inspect the existing schema carefully.

If PostgreSQL can safely enforce the invariant without a major schema redesign, add appropriate constraints.

If DB-level enforcement would require an unnecessarily complicated redesign, retain service-level validation and add strong integration tests.

Do not invent a generic ownership framework.

TESTS:

Use two users:

User A
User B

User A creates:
- account
- category
- transaction
- transfer

User B attempts:
- GET
- LIST
- UPDATE
- DELETE

and attempts to construct transactions/transfers referencing User A's financial resources.

Expected:
No cross-user access or mutation.

Also verify:
- summaries
- balances
- transaction lists
- transfer lists

do not leak User A data to User B.

============================================================
PHASE 6 — FINANCE OPENING BALANCE
============================================================

Only inspect:

- Account
- AccountService
- account DTOs
- account controller
- finance migration
- existing account tests
- BalanceCalculator

KNOWN ISSUE:

openingBalance is currently mutable.

But current balance is derived from:

opening balance
+ income
- expense
+ transfers

Therefore changing openingBalance after account creation changes the historical financial baseline.

PREFERRED PRODUCT-SAFE POLICY:

Opening balance should be immutable after account creation.

Corrections should eventually be represented as an explicit financial adjustment rather than rewriting the starting balance.

HOWEVER:

This may alter an existing API behavior.

Therefore:

1. Inspect current Account update API.
2. Inspect existing tests.
3. Determine whether mutable openingBalance is clearly intentional.
4. If there is no ambiguity, implement the safer immutable behavior.
5. If ambiguity exists, DO NOT invent product semantics.
6. STOP and report the decision required.

If implementing:
- update validation
- update service behavior
- update tests
- preserve other account update functionality

Do not implement a full adjustment-transaction feature during this pass.

============================================================
PHASE 7 — FINANCE CALCULATION TEST HARDENING
============================================================

Only inspect:

- BalanceCalculator
- FinanceTransactionRepository
- Transfer repository
- existing Finance tests

Add focused tests for:

1. opening balance only
2. income
3. expense
4. income + expense
5. transfers
6. zero transactions
7. multiple accounts
8. same-currency accounts
9. different-currency accounts

CRITICAL:

Do not aggregate INR and USD directly.

Different currencies must remain logically separate unless an explicit FX conversion mechanism exists.

Also test monetary boundaries consistent with:

NUMERIC(19,4)

Test:
- positive amount
- zero rejection
- negative rejection
- decimal precision
- valid large amount within schema limits

Do not use floating point for money.

If BalanceCalculator currently calculates every account when only one account is requested, determine whether a small targeted optimization is safe.

Do not perform a major repository redesign just for this.

============================================================
PHASE 8 — MEDICINE INTEGRITY
============================================================

Only inspect:

- V006__Medicines_schema.sql
- Medicine
- Schedule
- DoseRecord
- DoseService
- relevant repositories
- DTOs
- medicine/dose tests

KNOWN ISSUE 1:

A dose references both medicine and schedule, but the database does not fully guarantee:

dose.schedule.medicine == dose.medicine

GOAL:

A dose can only use a schedule belonging to the same medicine.

Prefer DB integrity if it can be added cleanly.

Otherwise enforce in the service layer and add integration tests.

KNOWN ISSUE 2:

Dose status/timestamp combinations need stronger integrity.

Desired:

TAKEN:
    takenAt required

MISSED:
    takenAt null

SKIPPED:
    takenAt null

Preserve the current policy that future takenAt values are rejected unless existing tests/product semantics clearly require otherwise.

TESTS:

- valid TAKEN
- TAKEN without takenAt
- MISSED with takenAt
- SKIPPED with takenAt
- future takenAt
- another user's medicine
- another medicine's schedule
- mismatched medicine/schedule

Do not implement medication reminders/push delivery.

============================================================
PHASE 9 — HABIT DATA INTEGRITY
============================================================

Only inspect:

- V005__Habits_schema.sql
- Habit
- HabitService
- Schedule
- Completion
- relevant DTOs
- repositories
- habit tests

KNOWN ISSUE:

Target fields are not sufficiently type-specific.

Supported types:

BOOLEAN
COUNT
DURATION

Desired semantics:

BOOLEAN:
    targetValue = null
    targetUnit = null
    targetMinutes = null

COUNT:
    targetValue > 0
    targetUnit != null
    targetMinutes = null

DURATION:
    targetMinutes > 0
    targetValue = null
    targetUnit = null

Implement:
- DTO/service validation
- database CHECK constraints where practical

Do not create complicated cross-table database logic.

Also inspect completion data.

A BOOLEAN habit should not accept COUNT/DURATION-specific completion data.

A COUNT habit should not accept arbitrary duration data.

A DURATION habit should not accept arbitrary count/value data.

Add focused tests for valid and invalid combinations.

============================================================
PHASE 10 — HABIT /today PERFORMANCE
============================================================

Only inspect:

- HabitService.today()
- directly related repositories
- directly related tests

KNOWN ISSUE:

The current implementation may perform:

1 query for habits
+
N schedule queries
+
N completion queries

This can become N+1/2N+1.

Determine whether schedules and today's completions can be batch-loaded cleanly.

If yes:
- implement a small targeted optimization
- preserve API behavior
- add regression tests

If optimization requires a large abstraction/refactor:
do not do it.
Report it as a future optimization.

============================================================
PHASE 11 — DIET DATA CONSISTENCY
============================================================

Only inspect:

- V002__Diet_module.sql
- water-related entity/DTO/service
- directly related tests

KNOWN ISSUE:

Water units currently allow inconsistent representations such as:

ml
mL
L
l
glass
glasses
cup
cups

Goal:
Use a canonical representation.

For example, an agreed canonical set such as:

ML
L
GLASS
CUP

But inspect the existing API/data model before deciding the exact representation.

IMPORTANT:
Do not break existing stored user data.

If migration is required:
- safely migrate existing values
- preserve records
- update tests

Also inspect the redundant profile index.

If UNIQUE(user_id) already creates the needed index, remove the redundant explicit index only if doing so is safe for the existing migration strategy.

Do NOT modify old Flyway migrations that may already have been applied in production.

If the migration is already released/applied, create a new migration instead of editing the old migration.

============================================================
PHASE 12 — DOCUMENT SECURITY REGRESSION
============================================================

Only inspect the existing Documents security implementation and tests.

Known implementation is already generally strong.

DO NOT redesign it.

Verify/add regression tests for:

- path traversal
- invalid extension
- MIME mismatch
- magic-byte mismatch
- oversized upload
- ownership isolation
- safe Content-Disposition
- no-store caching

Small cleanup is allowed:

If code uses:

extension.toLowerCase()

prefer:

extension.toLowerCase(Locale.ROOT)

Do not make unrelated document changes.

============================================================
PHASE 13 — NOTIFICATIONS SECURITY REGRESSION
============================================================

Only inspect:

- V010__Notifications_schema.sql
- DeviceRegistrationController
- DeviceRegistrationService
- ReminderService
- NotificationPreferencesService
- related repositories/entities/DTOs
- existing notification tests

Preserve current security model:

Push tokens:
- never returned
- never logged

Devices:
- current-user scoped

Reminders:
- current-user scoped

Verify unique:

(user_id, device_id)

Do not redesign polymorphic source_id.

Do not add FCM/APNs.

Do not implement actual push delivery.

Add regression tests proving push tokens never appear in API responses where applicable.

============================================================
PHASE 14 — GENERIC INTEGRATION TEST BASE
============================================================

Only inspect:

backend/src/test/java/com/blistra/AbstractIntegrationTest.java

KNOWN ISSUE:

The generic integration-test base contains direct cleanup knowledge of Finance tables.

For example, it directly deletes Finance tables during cleanup.

This creates unnecessary coupling.

Goal:

The base integration test should not have to understand every future domain module.

However:

Do NOT build a large test framework.

If a small safe improvement is possible, make it.

Otherwise report this as technical debt.

Most importantly:
Do not compromise Testcontainers.

============================================================
PHASE 15 — TESTCONTAINERS
============================================================

Known environment:

Windows
Docker Desktop
PostgreSQL
Testcontainers

Previous tests have failed before test methods execute because of Docker/Testcontainers compatibility.

Investigate ONLY the Testcontainers configuration and directly related files.

Do not:
- switch to H2
- remove Testcontainers
- disable integration tests
- skip tests
- mock database integration
- hardcode a Docker endpoint
- add environment-specific hacks that only work on one machine

Check:
- Testcontainers version
- Maven dependencies
- Docker client transport dependencies
- existing configuration
- actual error

If a safe compatibility fix exists:
implement it.

If the problem is an upstream Windows/Docker/Testcontainers compatibility issue that cannot safely be fixed in the repository:
do not fake a green build.
Report the exact blocker.

============================================================
PHASE 16 — CROSS-USER TEST MATRIX
============================================================

Do not inspect every module unnecessarily.

Use existing integration tests in each relevant module.

Strengthen tests for two-user isolation.

Minimum modules:

Finance
Documents
Health
Medicine
Habits
Planner
Notifications

For each module where CRUD/private resources exist:

User A creates resource.

User B:
- attempts GET
- attempts update
- attempts delete
- attempts list

Also test summary/list endpoints where applicable.

Expected:
User B must never receive User A's private data.

Prefer owner-aware repository/service queries.

Never trust client-supplied owner IDs.

============================================================
PHASE 17 — SPRINGDOC COMPATIBILITY
============================================================

Only inspect:

backend/pom.xml
springdoc configuration
existing OpenAPI-related code/tests

Current environment uses:

Spring Boot 4.1.1

Springdoc currently has a pinned version.

Do not blindly upgrade dependencies.

Determine whether the current version is actually compatible.

If incompatible:
make the smallest safe dependency/configuration change.

Verify application startup and relevant tests.

============================================================
PHASE 18 — LOW-PRIORITY CLEANUP
============================================================

Only if the earlier phases are stable:

1. Remove duplicate Lombok dependency.
2. Remove safe redundant Diet index via a NEW migration if necessary.
3. Use Locale.ROOT for document extension normalization.

Do not edit already-applied Flyway migrations.

============================================================
PHASE 19 — KNOWN LIMITATIONS — DO NOT IMPLEMENT
============================================================

The following are known but intentionally OUT OF SCOPE:

1. Per-user timezone support.

Current V1 uses configured UserTime timezone.

Do not redesign it.

2. Actual push-provider delivery.

Do not implement FCM/APNs.

3. Notification source_id universal foreign key redesign.

Keep current polymorphic approach.

4. Future dose timestamps.

Keep current manual-entry policy unless existing behavior clearly conflicts.

5. GENERAL reminder future-time policy.

Do not broaden or remove it.

6. Migration renumbering.

Do not renumber V001/V002/etc.

7. UPI.

8. SMS reading.

============================================================
PHASE 20 — MIGRATION SAFETY
============================================================

This project uses Flyway.

CRITICAL:

Never edit an old migration if it may already have been applied.

For schema changes:
- create a new migration
- use a new version number
- make it backward-safe
- consider existing data

Before adding a constraint:
- determine whether existing data violates it
- if data cleanup is required, report it rather than destroying data

Do not use destructive migrations casually.

============================================================
PHASE 21 — TEST EXECUTION
============================================================

After implementation:

First run focused tests for changed modules.

Then run:

.\mvnw.cmd clean test

Do not use:

-DskipTests

for final verification.

If Testcontainers prevents the suite from executing:
report it clearly.

If tests fail:
fix actual regressions.

Do not make tests green by weakening them.

Then run:

.\mvnw.cmd clean package

============================================================
PHASE 22 — FINAL DIFF REVIEW
============================================================

Run:

git status
git diff --stat
git diff

Review the complete diff.

Remove any unrelated modifications.

Check for:
- secrets
- tokens
- passwords
- PII logging
- debug code
- commented-out code
- unnecessary dependencies
- unnecessary abstractions
- destructive migrations
- skipped tests
- weakened assertions

============================================================
FINAL REPORT
============================================================

Return a structured report with:

1. BASELINE
   - initial test result
   - exact Testcontainers failure if present

2. CHANGES
   - every changed file
   - reason for each change

3. SECURITY
   - exception response safety
   - cross-user isolation
   - token/password logging
   - document security

4. DATA INTEGRITY
   - Finance
   - Medicine
   - Habits
   - Diet
   - Notifications

5. PLANNER
   - all-day task semantics
   - timezone behavior

6. DATABASE
   - migrations added
   - constraints added
   - timestamp strategy

7. TESTS
   - tests added
   - tests modified
   - tests executed
   - passed
   - failed
   - errors

8. BUILD
   - clean test result
   - package result

9. UNRESOLVED ISSUES
   - exact remaining problems
   - why they remain
   - whether they require a product decision/environment change

10. OUT-OF-SCOPE ITEMS
   - explicitly confirm that no new features were implemented

11. DIFF SUMMARY
   - concise summary of final patch

IMPORTANT:
Do not claim tests pass unless they actually executed and passed.
Do not claim Testcontainers is fixed unless the integration tests actually execute successfully.
Do not claim a security invariant is DB-enforced unless there is an actual database constraint.
Do not claim per-user timezone support.