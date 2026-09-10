# ADR-010 — Health Module Architecture

## Status

Accepted

## Context

The Blistra app requires a personal health tracking module covering profile,
measurements (weight, height, heart rate, temperature, blood pressure), sleep
records, activity, health observation logs, generic health events, and
appointments. The module must:

- Store all data per-user with strict ownership enforcement.
- Validate measurement units and ranges on the server.
- Expose a REST API with pagination and time-range filtering.
- Provide a Flutter frontend with offline-capable token persistence.
- Avoid logging any sensitive health data.

## Decision

1. **Backend module structure** — A dedicated `health` Spring Boot module under
   `com.blistra.health` with the standard layers: `domain` (JPA entities +
   enums), `repository` (Spring Data with `findByIdAndUserId` and `@Query`
   search), `dto` (Lombok `@Data @Builder` request/response records),
   `application` (services + `MeasurementValidator`), `controller` (REST
   endpoints under `/api/v1/health/*` with OpenAPI annotations).

2. **Database schema** — Flyway migration `V004__Health_schema.sql` creates
   seven tables (`health_profiles`, `health_measurements`, `health_sleep_records`,
   `health_activities`, `health_symptom_logs`, `health_events`,
   `health_appointments`). All tables have `user_id UUID NOT NULL` with
   `ON DELETE CASCADE` FK to `users.id`. Constraints enforce:
   - Measurement units per type (KG/LB, CM/IN, BPM, C/F, MMHG).
   - Blood pressure requires systolic > diastolic and diastolic present.
   - Sleep rating 1–5.
   - Severity (MILD/MODERATE/SEVERE), EventType, AppointmentStatus enums.
   - Indexes on `(user_id, timestamp)` for every time-series table.

3. **Ownership enforcement** — Every repository query scopes to the
   authenticated user via `CurrentUserProvider` (resolves `User` from Spring
   Security context). Controllers never accept a `userId` parameter; cross-user
   access returns 404 (`ResourceNotFoundException`). Profile is a singleton per
   user (upsert via PUT).

4. **Validation** — `MeasurementValidator` (server-side) enforces
   physiologically plausible ranges and unit-type pairing. DTOs carry
   Bean Validation annotations (`@NotNull`, `@DecimalMin`, `@PastOrPresent`).
   Errors surface via `GlobalExceptionHandler` as `ApiErrorResponse`
   (status, code, message, fieldErrors).

5. **Timestamps** — `OffsetDateTime` (UTC) for user-supplied moments
   (`measuredAt`, `observedAt`, `scheduledAt`), `LocalDateTime` (UTC) for
   audit columns (`createdAt`, `updatedAt`) maintained by `update_timestamp()`
   trigger. `dateOfBirth` is `LocalDate` (no time component).

6. **Frontend** — Flutter feature under `lib/features/health/`:
   - `health_models.dart` — typed enums (with explicit `wire` values matching
     backend enum names) and DTOs (`fromJson` / `toJson`).
   - `health_api.dart` — thin typed wrapper around shared `ApiClient`
     (JWT header, timeout, `ApiErrorResponse` → `ApiException`).
   - `health_repository.dart` — `ChangeNotifier` caching latest page per
     resource; create/update/delete auto-refresh.
   - `presentation/` — generic `RecordListScreen<T>` + `FormScaffold` reduce
     boilerplate for seven resources; per-resource form screens handle
     validation and enum dropdowns.
   - Auth uses the shared `AuthController` + `SessionStore` (shared_preferences)
     for token persistence; `LoginScreen` drives register/login/logout.

7. **API contract** — Endpoints:
   - `GET/PUT /api/v1/health/profile`
   - `GET/POST /api/v1/health/measurements` (query: type, from, to, page, size)
   - `GET/POST /api/v1/health/sleep`
   - `GET/POST /api/v1/health/activity`
   - `GET/POST /api/v1/health/logs`
   - `GET/POST /api/v1/health/events`
   - `GET/POST /api/v1/health/appointments`
   - All list endpoints return `PageResponse<T>{content,page,size,totalElements,totalPages,last}`.
   - Create returns 201 with resource; update returns 200; delete returns 204.

8. **Privacy** — No `logger` / `log` / `println` / `System.out` / `debugPrint`
   on health data in backend or frontend code. Backend `GlobalExceptionHandler`
   logs only request path and error code, never request body.

## Alternatives Considered

- **Single generic `health_records` table with JSONB payload** — Rejected;
  strong typing, constraints, and indexes per domain are critical for data
  quality and query performance.
- **Client-side validation only** — Rejected; server is the trust boundary
  (ADR-007).
- **Separate microservice for Health** — Rejected per ADR-001 (modular
  monolith) and ADR-009 (avoid premature distribution).
- **FHIR integration from day one** — Deferred; the internal model is
  FHIR-inspired but mapping to FHIR resources is a future concern.

## Consequences

- **Positive**: Clear module boundaries, compile-time safety on both sides,
  strong DB constraints prevent invalid data, ownership model eliminates IDOR.
- **Cost**: Seven tables + indexes increase schema size; seven REST resources
  increase API surface. Migration version `V004` skips `V002`/`V003` (taken by
  Diet/Medicines agents on the shared branch) — acceptable since Flyway
  versions need only be unique and ordered.
- **Risk**: Concurrent agents on the same branch may introduce merge conflicts
  in `pom.xml` (temporary test profile) and `pubspec.yaml` (duplicate `http`
  dep). The temporary Maven profile `temporary-health-tests` must be removed
  before merge.

## Revisit Conditions

- If FHIR interoperability becomes a hard requirement, add a mapping layer
  and consider a dedicated FHIR server.
- If measurement types expand significantly, evaluate an EAV or JSONB
  extension table instead of adding columns.
- If per-resource RBAC is needed (e.g. share specific records with a clinician),
  extend the ownership model with explicit ACLs.