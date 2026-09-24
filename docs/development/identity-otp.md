# Blistra V1 Identity, OTP & Profile — Development & Production Guide

## Account model

One account, three login identifiers: **username**, **email**, **phone**.
All three resolve to the same `users` row (`IdentifierType` classification in
`IdentityNormalizer`: `@` → email, international digits → phone, else
username). Login accepts any of them in the single `identifier` field
(`LoginRequest.email` remains as a deprecated alias).

- Usernames: 3–30 chars `[A-Za-z0-9_.]`, case-insensitive unique
  (`users_username_ci_unique`), server-side normalized.
- Emails: lowercase-trimmed, case-insensitive unique.
- Phones: canonical E.164 (`+[1-9][0-9]{6,14}`), unique when present, never
  regionally guessed — the country code is required.
- Passwords: bcrypt (`BCryptPasswordEncoder`), 8+ chars with a letter and a
  digit, enforced identically in Bean Validation and the Flutter validators.
- Lifecycle: `PENDING_VERIFICATION` → `ACTIVE` once the required channels
  verify. `INACTIVE`/`SUSPENDED` cannot authenticate anywhere (login, JWT
  filter, `CurrentUserProvider`).
- JWT subjects are user ids for new tokens; legacy email-subject tokens keep
  working (`CustomUserDetailsService.loadBySubject`).

`UserProfile` (`user_profiles`, one row per user, created atomically with the
account) holds display/locale data only. Health measurements stay in the
Health domain; diet preferences in the Diet domain. Age is derived from
`dateOfBirth` on every read, never stored.

## OTP design

- 6-digit `SecureRandom` codes, 10-minute TTL (`blistra.otp.ttl-minutes`),
  single-use, max 5 attempts (`OTP_*` error codes: `INVALID_OTP`,
  `EXPIRED_OTP`, `TOO_MANY_ATTEMPTS`).
- Only SHA-256(code + pepper) is stored (`verification_otps.code_hash`).
- Resend cooldown 60s → HTTP 429 `RESEND_COOLDOWN` with `retryAfterSeconds`
  (the Flutter OTP screen counts down from it); hourly cap 10 per
  (user, purpose) → 429 `RATE_LIMITED`.
- Attempt counting and consumption commit in an isolated transaction before
  the outcome is reported, so failures can never roll the counter back.
- Purposes: `EMAIL_VERIFY`, `PHONE_VERIFY`, `PASSWORD_RESET`,
  `EMAIL_CHANGE`, `PHONE_CHANGE`. New codes supersede older ones per purpose.
- Recovery (`forgot-password`/`reset-password`) is permitAll and always
  returns the same generic message (anti-enumeration).

## Local development OTP (dev mode)

`application-dev.yml` sets `blistra.otp.dev-mode: true` by default. In this
mode:

1. Codes are real random OTPs with full expiry/attempt/cooldown enforcement —
   nothing is hardcoded.
2. The backend logs a clearly marked line (destination masked):
   `[DEV ONLY] Email verification OTP generated. Account: te***@example.com OTP: 483921 ...`
3. The authenticated dev endpoint returns the latest usable code:
   `GET /api/v1/auth/dev/otp?purpose=EMAIL_VERIFY` (Bearer token from
   register/login). Purposes: `EMAIL_VERIFY`, `PHONE_VERIFY`,
   `PASSWORD_RESET`, `EMAIL_CHANGE`, `PHONE_CHANGE`.
4. The Flutter OTP screen uses the same verify API in dev and production.

To test locally: register in the app → read the code from the backend
console or the dev endpoint → enter it. No production code path exposes it.

## Production configuration (required)

- `BLISTRA_OTP_DEV_MODE=false` (disables console senders + dev endpoint;
  the endpoint 404s).
- `BLISTRA_OTP_PEPPER=<long random secret>` (startup fails without it).
- Provide real `EmailSender`/`SmsSender` beans (SMTP service / SMS gateway);
  without them, verification fails closed with 503
  `VERIFICATION_UNAVAILABLE` — codes are never faked or logged.
- `JWT_SECRET` (≥32 bytes), database credentials, as before.
- Optional tuning: `BLISTRA_OTP_TTL_MINUTES`, `BLISTRA_OTP_MAX_ATTEMPTS`,
  `BLISTRA_OTP_RESEND_COOLDOWN`, `BLISTRA_OTP_MAX_PER_HOUR`.

## Endpoints (all under `/api/v1`)

Auth (public): `POST /auth/register`, `POST /auth/login`,
`POST /auth/forgot-password`, `POST /auth/reset-password`.
Auth (authenticated): `POST /auth/verify/email`, `POST /auth/verify/phone`,
`POST /auth/resend/email`, `POST /auth/resend/phone`,
`POST /auth/change-password`, `GET /auth/dev/otp` (dev only).
Profile (authenticated): `GET /profile`, `PUT /profile`,
`POST /profile/complete-onboarding`, `POST /profile/identity`,
`POST /profile/identity/confirm?channel=EMAIL|SMS`.

Email/phone changes are staged as `pending_*` and swap only after OTP
confirmation; the old verified value stays live until then. Identity changes
require the current password.
