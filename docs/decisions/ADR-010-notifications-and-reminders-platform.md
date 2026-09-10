# ADR-010 — Notifications and Reminders Platform

## Status

Accepted

## Context

Blistra's domains manage their own business records: Medicine owns medication schedules, Habits owns recurrence, Planner owns tasks and events, and Health owns appointments. Users also want reminders (e.g. "call the dentist") that are not tied to any of those records.

We needed a delivery mechanism that answers two questions for the user:

- **When** should I be reminded?
- **How** should the reminder be delivered?

Notifications and Reminders is that mechanism. It is explicitly **not** the owner of any underlying business event. If a medicine schedule changes, the Medicines module is authoritative and must drive the resulting reminder change; Notifications must not duplicate or overwrite that authority.

The app has no push infrastructure (no Firebase, no APNs), and the initial platform priority is Android. Notifications therefore have to work through **local (client-side) scheduling**, while the backend remains the source of truth for what reminders exist and when they are enabled.

## Decision

- Notifications is a separate module owning three things:
  - `reminders` — what to remind, when (an absolute instant), in which IANA timezone, and its current state.
  - `notification_preferences` — per-user toggles (global + per category) and a `hide_sensitive_content` switch that keeps domain reminder content generic on lock screens.
  - `device_registrations` — device records for a future push provider. Push tokens are stored but **never returned by any API and never logged**.
- Reminder ownership is always derived from the authenticated security context. No API accepts a user id; every read/write is scoped to the current user. Cross-user access resolves to 404.
- **Only `GENERAL` reminders can be created by clients.** `MEDICINE`, `HABIT`, `PLANNER`, and `HEALTH` reminders are created by their owning module, which remains authoritative for the underlying lifecycle.
- `source_id` is a soft reference back to the owning module's record. It deliberately has **no foreign key** because the target table is polymorphic by reminder type. The owning module enforces referential integrity in its application layer.
- Reminder state is intentionally minimal: `SCHEDULED` and `CANCELLED`. We do not model fake delivery/pending/failed states; real delivery feedback only becomes meaningful with a push provider.
- `scheduled_at` is stored as an absolute instant (`TIMESTAMPTZ`, UTC) and the user's IANA `timezone` is stored alongside it for display. Storing an instant, not a naive wall-clock, means a reminder scheduled for 8:00 AM Kolkata stays at the correct instant regardless of server or device timezone.
- The backend validates the timezone identifier and rejects past `scheduled_at` values (400 `INVALID_REMINDER_TIME`). Past reminders cannot exist; cancellation is the way to stop a reminder.
- Delivery in the initial version is **client-side local scheduling**: the Flutter app fetches the user's `SCHEDULED` reminders plus preferences, reschedules local notifications on the device, and applies preference toggles and `hide_sensitive_content`. This requires no push provider and works when the device is off-line (within the limits of local notifications).
- Device registration endpoints exist now so that a future push provider has the token store ready, but no notification is pushed in this version.

## Alternatives Considered

- **Server-side push (Firebase Cloud Messaging / APNs):** eliminates client-scheduling divergence and enables server-triggered sends, but adds a provider dependency, vendor keys, and operational complexity. Rejected for the initial version; the device-token schema is in place to make the migration additive rather than a rewrite.
- **Full delivery-state tracking (`DELIVERED`, `READ`, `FAILED`):** implies an endpoint that can observe the device, which we do not have. Modelling states we cannot honestly observe would create false confidence in the data. Rejected.
- **Foreign key from `reminders.source_id`:**
  - A foreign key to `users` (single target) breaks when the target is a medicine, habit, planner task, or health appointment.
  - Multiple FKs (one per owning table) makes `source_id` the widest-cast column and forbids `GENERAL` rows cleanly.
  Rejected in favour of a soft reference with a `CHECK` that enforces the invariant (`GENERAL` ⇒ `source_id IS NULL`, other types ⇒ `source_id IS NOT NULL`).
- **Duplicate-prevention through naive ids on the client:** local notification ids are derived with a stable hash of the reminder id so resync is idempotent (cancel-all then re-schedule) without duplicates.

## Consequences

- The Flutter client owns the timing of delivery; if the app is killed or the OS suppresses notifications, a reminder can be missed. This is acknowledged for the initial Android-first version and is bounded by the local-notification scheduling window that the OS allows.
- Adding push later requires a service worker/FCM sender plus turning device tokens on — no schema redesign is needed.
- Each owning module owns reminder mutations for its domain; cross-module coupling is limited to a read-only helper contract that Notifications exposes.
- `timezone` must always be stored; the client must send the user's IANA zone when creating reminders, otherwise validation fails with a clear 400.

## Revisit Conditions

- Revisit when a push provider (FCM/APNs) is introduced: server-side send, delivery states, and possibly storing device-level `DELIVERED` outcomes.
- Revisit when a domain genuinely needs a repeating (cron-like) reminder: today Medicine owns recurrence; Notifications should not grow its own recurrence engine unless a real `GENERAL` recurring-reminder requirement appears.
- Revisit `source_id` consistency if a domain requires reminders that do not map 1:1 to a single owning record.