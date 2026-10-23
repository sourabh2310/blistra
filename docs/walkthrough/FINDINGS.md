# Android walkthrough findings (emulator, Pixel_6 API 36, 2026-10-24)

Method: debug build on the emulator against the local backend, driven with adb, recorded in segments
(`01-auth.mp4` ... `08-reminders.mp4`). Test accounts: `qatester`, `zedtest1` (dev database only).
Scope of fixes in this pass: auth, navigation, profile, dashboard. Other modules are logged only.

Severity: High = blocks a flow or loses data; Medium = wrong or confusing behaviour; Low = polish.

## Fixed in this pass

| # | Area | Screen | Steps | Expected | Actual | Sev | Status |
|---|------|--------|-------|----------|--------|-----|--------|
| F1 | Dashboard | Home > This week | Tap the week card | Weekly details screen opens | Nothing happened; `HOME/WEEK` route was never linked | Medium | Fixed (card and "Details ›" header) |
| F2 | Auth | Forgot password, register steps | Press system Back | Return to previous step / sign-in | App exited | Medium | Fixed (`PopScope` in `auth_screen.dart`) |
| F3 | Auth | Registration end ("You're all set") | Register without verifying email via inline OTP, finish profile and health steps, tap Go to Blistra | Prompt to verify email | Stuck on the screen with "Onboarding incomplete. Missing: email verification." and no way to act; only killing the app got out | High | Fixed (resume step and failure path now go to the email OTP screen) |
| F4 | Navigation | Hub / Home | Blistra AI entry points | Parked until launch | FAB and Hub tool were live | n/a | Hidden behind `AppConfig.aiEnabled` (false), Hub tool shows "Coming soon", code kept |
| F5 | Build | Android on Windows | `flutter run` with pub cache on C: and project on D: | Builds | Kotlin incremental cache failure | High | Fixed (`kotlin.incremental=false`) |

F2 and F3 were re-verified on the emulator after a rebuild: Back from forgot-password and register returns to the
previous step, and a fresh registration now lands on "Verify your email", then completes onboarding.

## Auth, navigation, profile, dashboard: second pass

| # | Screen | Steps | Expected | Actual | Sev | Status |
|---|--------|-------|----------|--------|-----|--------|
| A1 | Sign-in | Fail a sign-in, then edit the fields | Error clears while typing | "Your sign-in details don't match" stays until next submit | Low | Fixed |
| A2 | Register | Type a 2-char or invalid-character username | Inline message | No inline message; only the live "Available" check is silent | Medium | Fixed |
| A3 | Register | Enter `notanemail` or `123` as phone | Inline message / Send OTP disabled | No message; phone "Send OTP" enabled for `123` | Medium | Fixed |
| A4 | Register health step | Leave unit on ft/lbs, enter 175 | Client-side range check | Generic "We couldn't save your health details" from the server; default units are ft/lbs although country is India | Medium | Fixed (unit-aware range check and message; toggle label now "in"; default unit still follows device locale) |
| A5 | Register health step | Weight field | Numeric only | Accepts `abc` | Low | Fixed |
| A6 | "You're all set" | Read stat card | Matches Hub | Says "6 modules"; Hub has 8 | Low | Fixed |
| A7 | Sign-in (dark) | Disabled Sign in button | Readable label | Dark text on mid green, low contrast | Low | Fixed (disabled button colours) |
| A8 | Date picker (manual entry) | Type `01/01/2090` as birthday | Rejected as out of range | No visible message; value left unconfirmed | Low | Fixed (explicit messages, real-date and future-date checks; not re-run on device) |

## Other modules

| # | Module | Screen | Steps | Expected | Actual | Sev | Status |
|---|--------|--------|-------|----------|--------|-----|--------|
| M1 | Medicines | Medicine detail | Add a medicine, open it from My medicines | Detail page | "This medicine couldn't load" with Retry; backend returned 200 for every call, so the failure is client-side (see `MedicineDetailPage`) | High | Fixed: refills endpoint returns a paged envelope, client now accepts it. Verified on emulator |
| M2 | Habits | New habit sheet | Name "Read book", Yes/no, Create habit | Habit created, sheet closes | Spinner forever; no `POST /api/v1/habits` reaches the backend (reproduced twice, also after fixing a validation error on Count target) | High | Fixed: `showHabitFormSheet` built the sheet above `HabitsScope`, so `HabitsScope.of` threw after the spinner started. Verified on emulator |
| M3 | Finance | New expense | Leave "What was it for?" empty, or amount empty / negative / 99999999999999, tap Save | Inline error | Save does nothing and shows no message | Medium | Fixed: errors also shown as a snackbar, amount must be > 0 and <= 1,000,000,000. Verified |
| M4 | Finance | New expense | Amount 99999999999999 | Upper bound | Accepted in the field | Low | Fixed (same check) |
| M5 | Diet | Add item | Calories 99999999 | Upper bound | No error | Low | Fixed: calories <= 20000, grams <= 5000, quantity <= 100000 |
| M6 | Diet | Meal item row | Add item with quantity 100 | "100 g" style | Shows `100, 350 kcal`, unit missing | Low | Not a bug: unit was left empty in the test |
| M7 | Health | Add measurement | Systolic 300 / diastolic 400 | Plausible-range check | Only "Systolic must be greater than diastolic"; the error banner is nearly invisible | Medium | Fixed: systolic/heart rate <= 300, diastolic <= 200. The faint banner was a snackbar caught mid-fade |
| M8 | Medicines | New medicine | Strength -5 | Readable message | Message truncated ("Strength cannot be neg...") | Low | Fixed: shorter messages, non-numeric input says "Enter a number" |
| M9 | Reminders | New reminder | Open the form | Device timezone | Timezone dropdown defaults to UTC while time is local; confirm the stored instant is correct | Medium | Not a bug: the emulator timezone is UTC and the stored instant is correct |
| M10 | Reminders | Upcoming tab | Look for delete | Discoverable delete/undo | Only "Swipe a general reminder left to cancel it" on the All tab; no undo | Low | Fixed: "Cancel this reminder" button with confirmation in the edit form |
| M11 | Planner | Event form | Empty title, then Create event | Inline error | No message observed | Low | Not a bug: button is disabled until a title is typed; end-before-start already shows a message |
| M12 | Quick add | Add medicine / task | Save from Planner tab | Land on the new item or its module | Returns to Planner | Low | By design: quick add returns to the screen you were on |

## Verified working

Sign-in, sign-out, wrong password, long and special-character identifiers, dark-mode toggle, Google account picker
(opened only, no account chosen), forgot password end to end, registration happy path, profile sub-screens, Hub tiles,
Planner task create/edit/complete/delete, Diet meal and water, Health measurement create/delete, Finance expense
create/delete, Reminders create/cancel.

## Not covered

- Emoji input (adb `input text` cannot type emoji), pull to refresh, Documents upload (needs a file on the device),
  friends/groups in Finance, Habits check-ins (blocked by M2), medicine schedules and dose logging (blocked by M1).
- `docs/walkthrough/01-auth.mp4` only covers the first 175 seconds of the auth flow; later auth steps were driven
  without a recording.

