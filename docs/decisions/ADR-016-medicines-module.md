# ADR-016 — Medicines Module: Personal Medication Tracking

## Status

Accepted

## Context

The Blistra app needs a personal medication tracking module. Users must record medicines, recurring dosing schedules, individual dose events (taken/missed/skipped), and refill history. This is **user-recorded data only** — the app provides no medical advice, dosage calculations, or drug interaction warnings.

Key requirements:
- Medicines have name, generic name, form, strength, dates, and status (ACTIVE/PAUSED/COMPLETED/ARCHIVED)
- Schedules support DAILY, WEEKLY, CUSTOM_DAYS, and AS_NEEDED recurrence
- Dose events are recorded by the user at specific moments (no auto-marking as missed)
- Refill records track quantity and remaining amount
- All data is strictly user-owned; cross-user access must be prevented

## Decision

### Backend Architecture
- New Spring module `com.blistra.medicines` under the modular monolith
- Four Flyway-managed tables: `medicines`, `medication_schedules`, `dose_records`, `refills`
- All timestamps stored as `TIMESTAMPTZ` (`OffsetDateTime`); day boundaries defined by client `date` + `offsetMinutes` (following ADR-014)
- Schedule recurrence stored as wire arrays:
  - `times` → comma-separated `HH:mm` strings via `AttributeConverter`
  - `days_of_week` → comma-separated DayOfWeek names via `AttributeConverter`
- Dose records use `OffsetDateTime` for `scheduled_at` and `taken_at` (millisecond precision)
- Soft-delete for medicines: `DELETE /medicines/{id}` → `status = ARCHIVED` (preserves dose/refill history)
- Deleting a schedule preserves dose records via FK `ON DELETE SET NULL`
- REST endpoints under `/api/v1/medicines`, `/api/v1/medicines/{medicineId}/schedules`, `/api/v1/medicines/{medicineId}/doses`, `/api/v1/medicines/{medicineId}/refills`
- All queries scoped to authenticated user via `CurrentUserProvider` (ADR-007, ADR-015)
- Cross-user access returns 404 (not 403); client never sends userId
- Validation via Jakarta Bean Validation on DTOs; cross-field checks (`@AssertTrue`) for date ordering

### Frontend Architecture
- Flutter feature under `lib/features/medicines/`
- Models mirror wire format: enums with `wire` property for serialization
- `MedicinesApiClient` thin wrapper over `http.Client` with token injection from `AuthState`
- State via `ChangeNotifier` controllers:
  - `MedicineListController` (pagination + status filter)
  - `MedicineDetailController` (medicine + schedules + recent doses + refills + record dose)
  - Form controllers with local validation (`MedicineFormController`, `ScheduleFormController`, `RefillFormController`)
- Screens: login/register, medicine list, medicine form, medicine detail (with quick dose recording), schedule form, refill form, dose history
- Auth via shared `AuthState` + `ApiClient` (in-memory token per ADR-010/finance stack); logout clears token

## Alternatives Considered

### 1. Auto-mark missed doses
- **Rejected**: Users should consciously record every dose. Auto-marking assumes non-adherence and creates noisy data.

### 2. Hard delete for medicines
- **Rejected**: Archiving preserves dose/refill history for trend analysis and export. Soft delete is reversible.

### 3. RRULE or cron for schedules
- **Rejected**: Over-engineered for user-recorded medication. Simple enum + time arrays + optional days covers 95% of use cases. AS_NEEDED covers the rest.

### 4. Frontend state management with Riverpod/Bloc
- **Rejected**: `ChangeNotifier` + `ListenableBuilder` is sufficient for this module's scope, has zero dependencies, and integrates naturally with Flutter's widget tree.

### 5. Backend-generated dose instances
- **Rejected**: Scheduling engine adds significant complexity. User-recorded doses are more flexible (handles "took it early/late", skipped intentionally, as-needed).

## Consequences

**Benefits**
- Clean separation: medicines = definitions, schedules = when, doses = actual events, refills = supply
- Full history integrity: archive/deletion never loses dose or refill records
- Timezone-correct: all timestamps are `OffsetDateTime`; client sends local time with offset
- Secure by default: ownership enforced server-side, 404 on cross-user access
- Testable: controllers use fake API clients; models have serialization round-trip tests

**Costs/Risks**
- Manual dose recording requires user discipline (mitigated by quick-record buttons on detail page)
- Schedule representation is bespoke (comma-separated strings); migration to RRULE later would require data migration
- Frontend in-memory auth token means login lost on app restart (acceptable for MVP; persistent session can be added later via `SessionStore`)

## Revisit Conditions

- If users demand automatic missed-dose detection → reconsider schedule engine
- If drug interaction database integration becomes a requirement → new AI tool capability (ADR-008)
- If persistent sessions are needed → integrate `SessionStore` with `AuthState`
- If schedule complexity grows (e.g., "every 2 weeks") → evaluate RRULE migration

---

See also: [ADR-007 — Server-Side Authorization](../ADR-007), [ADR-014 — Date/Time Handling in Diet](../ADR-014), [ADR-015 — Ownership & IDOR Protection](../ADR-015)