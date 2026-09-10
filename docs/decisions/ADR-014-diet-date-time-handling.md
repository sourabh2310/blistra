# ADR-014: Date/Time Handling in Diet

## Status
Accepted

## Context
Diet records are inherently tied to the user's local calendar day: "what did I eat *today*?" A server-side UTC day would split a user's breakfast and late-night snack across two days for anyone outside UTC, and daylight-saving transitions would create gaps or overlaps. The backend must never use server-local time for day boundaries.

## Decision
- **Storage:** All timestamps (`consumed_at` on meals, meal items (implicit via meal), water records) are stored as `TIMESTAMPTZ` (`OffsetDateTime` in Java). They always carry an explicit UTC offset.
- **Day definition:** A "local calendar day" is defined by the pair `(date, offsetMinutes)`. `date` is the ISO date (`YYYY-MM-DD`) of the user's local day. `offsetMinutes` is the user's UTC offset in minutes (e.g., `+330` for IST, `-300` for EST). The backend computes the day window as `[date at 00:00+offset, date at 24:00+offset)` and queries `consumed_at` within that half-open interval.
- **Client responsibility:** The client (Flutter app) sends `offsetMinutes = DateTime.now().timeZoneOffset.inMinutes` with every day-scoped request (meals list, water list, daily summary). The `consumedAt` field sent on create/update is formatted as ISO-8601 with offset (`isoWithOffset` helper: `2026-08-10T12:00:00+05:30`).
- **Validation:** The backend enforces `@PastOrPresent` on `consumedAt` — future timestamps are rejected. The client UI should default pickers to "now" and disable future dates/times.
- **Day navigation:** The UI shows a day selector with prev/next/today controls. Changing the day reloads the summary with the new `date` and current `offsetMinutes`.

## Consequences
- No DST surprises: the offset is fixed per-request based on the device's current timezone setting. If the user travels, the new offset applies to subsequent requests; historical data stays correct because it was stored with the original offset.
- No server timezone configuration needed; the backend is timezone-agnostic.
- The same `offsetMinutes` parameter works for meals, water, and summary endpoints, guaranteeing consistent day grouping across all Diet resources.
- Tests use fixed past dates (August 2026) and explicit offsets to remain deterministic.