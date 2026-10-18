# Deploying Blistra and testing the signed Android APK

Stack: existing Neon PostgreSQL + **free Render web service** + configured SMTP + GitHub Actions. Documents and avatars now use PostgreSQL binary storage, so no paid Render disk is required. The blueprint uses `plan: free` with no disk. This supersedes the earlier paid-volume proposal. No hosting purchase has been made.

Store credentials in a password manager or provider secret store. Never commit them to this repository or paste them into public build logs.

## Existing deployment: preserve data first

Previously uploaded files stored only in `/tmp` or the old container cannot be reconstructed from document metadata. Preserve any existing file backup; files already lost on a restart must be restored or re-uploaded. There is no silent fallback to ephemeral file storage. New PostgreSQL-mode uploads and their metadata commit together and survive application-container replacement. Migration V118 adds the binary-object table; it does not invent missing historic bytes. Preserve existing JWT/OTP secrets unless deliberately rotating them.

For an existing Render service, set `DOCUMENTS_STORAGE_BACKEND=postgres` and optionally `DOCUMENTS_MAX_TOTAL_BYTES=67108864` in **Environment**. Remove a manually configured filesystem backend override. `DOCUMENTS_STORAGE_ROOT` is unused in PostgreSQL mode. Set `BLISTRA_OTP_DELIVERY_KEY` before redeploying as described below. Committing a blueprint does not update a manually created Render service's environment.

The 64-MiB aggregate logical upload cap leaves room for the rest of the database. It covers documents and avatars, not PostgreSQL indexes, retained history or backup overhead. Monitor actual project usage in Neon; a quota is not a promise of unlimited free hosting. Current provider allowances are documented in [Neon plans](https://neon.com/docs/introduction/plans). Render's sleep, bandwidth, build and SMTP restrictions still apply: [free instance limitations](https://render.com/docs/free).

Migrations V109–V118 add session versions, deletion queues, rate limits, settlement decisions, trip groups, finance snapshots/archival and durable OTP delivery. V118 adds database binary storage. In optional filesystem mode, upload markers allow interrupted uploads to be reconciled. Existing payments retain their balance effect as `LEGACY_RECORDED`; new payments require confirmation. Configure `BLISTRA_OTP_DELIVERY_KEY` before deploying the new backend. Deploy the matching app together after a staging migration and backup restore drill. Do not run automatic down-migrations against live shared-finance data. See [operations.md](operations.md) for the proposed backup retention, monitoring and remaining owner decisions.

## 1. Neon (database)

Production OTP delivery now uses a database outbox (migration V115). Before deployment, create `BLISTRA_OTP_DELIVERY_KEY` using a cryptographically random 32-byte key encoded as base64, for example `openssl rand -base64 32`. Store it separately from the database and the OTP pepper, and preserve it across restarts. Startup fails if the key is missing or malformed. AES-256-GCM encrypts queued codes with the OTP ID as authenticated context. Successful, expired and exhausted deliveries erase the queued ciphertext. The database retains only the verification hash in production.

On PowerShell 7, generate the delivery key directly into the clipboard, then paste it into Render's secret environment field (never into chat or a committed file):

```powershell
[Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32)) | Set-Clipboard
```

Generate once, preserve the configured value across deploys, and clear the clipboard after saving it securely.

The worker polls every five seconds, claims ten items per batch with two-minute recovery leases, and retries at most five provider attempts within the original code lifetime. Provider I/O holds no database connection. A process crash after provider acceptance can deliver the same code more than once; delivery is at least once. Codes become usable after acknowledgement commits, and a failed replacement preserves the last delivered code. A resend while delivery is pending reuses that queued code. Monitor queue count/oldest age and SMTP failures; a mail outage must not trigger repeated manual restarts. Drain the queue before rotating the delivery key, or deliberately cancel outstanding requests and ask users to request new codes. Old database backups containing ciphertext must be protected alongside key backups.

1. Sign up at neon.tech and create a project (any region close to you). Keep the default database.
2. Open the project dashboard, press **Connect**, turn **Connection pooling off**, and copy the connection string. It looks like:
   `postgresql://USER:PASSWORD@ep-xxxx.region.aws.neon.tech/neondb?sslmode=require`
3. Convert it to the three values Render needs:

   | Render variable | Value |
   |---|---|
   | `DB_URL` | `jdbc:postgresql://ep-xxxx.region.aws.neon.tech/neondb?sslmode=require` (the host and database from the string, prefixed with `jdbc:postgresql://`, no user or password) |
   | `DB_USERNAME` | the `USER` part |
   | `DB_PASSWORD` | the `PASSWORD` part |

The backend creates its tables itself on first start (Flyway).

## 2. Brevo (verification email)

1. Configure an SMTP provider and verify the sending identity/domain. Check its current quotas and pricing.
2. **Senders, Domains & Dedicated IPs → Senders → Add a sender.** Use an email address you own (a Gmail address works) and confirm the email Brevo sends you.
3. **SMTP & API → SMTP.** Copy the **Login** (looks like `a1b2c3@smtp-brevo.com`) and generate an **SMTP key**.

| Render variable | Value |
|---|---|
| `MAIL_USERNAME` | the Brevo SMTP login |
| `MAIL_PASSWORD` | the SMTP key |
| `MAIL_FROM` | the sender address you verified |
| `MAIL_PORT` | a port supported by both your host and SMTP provider; blueprint default `2525` |

## 3. Render (backend)

1. Sign up at render.com with your GitHub account.
2. Review `render.yaml` for service `blistra-api`, branch `main`, `plan: free`, PostgreSQL storage and readiness health checks. For your existing service, preserve its intended deployment branch and configure its environment directly; do not create a duplicate service merely to apply the blueprint.
3. Fill in `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`, `BLISTRA_OTP_DELIVERY_KEY`, `DOCUMENTS_STORAGE_BACKEND=postgres`, and `BLISTRA_CORS_ORIGIN_PATTERNS` (exact browser origins; native apps do not rely on CORS). New services generate `JWT_SECRET` and `BLISTRA_OTP_PEPPER`; preserve existing values during migration. Keep `SPRING_PROFILES_ACTIVE=prod` and OTP dev mode disabled.
4. Apply only after the backup/migration and policy checks below are complete. Inspect the proposed resources before confirming any charges.
5. Check `https://<your-service>.onrender.com/actuator/health/readiness`. It must report `UP` with HTTP 200; PostgreSQL storage readiness does not require a local mounted directory. Upload a disposable document, redeploy, then confirm it still downloads. The origin without that path is the app's API URL.

Filesystem storage remains an explicit optional backend for a host with a durable volume: set `DOCUMENTS_STORAGE_BACKEND=filesystem` and mount `/var/data`, with `DOCUMENTS_STORAGE_ROOT=/var/data/blistra-documents`. That mode retains the mount guard and requires an appropriate paid/durable host. Do not select it on Render Free.

Configure monitoring for readiness, error rates, API latency, database upload budget and actual Neon project usage. Filesystem free-space/deletion-worker monitoring applies only to the optional filesystem backend; retain historic deletion-queue rows until old bytes are accounted for. Confirm how the host supplies the client address before tuning authentication limits; do not blindly trust client-supplied forwarding headers. Current budgets are 100 auth requests per source/15 minutes and 20 logins per account/15 minutes. A shared proxy address can incorrectly combine users without trusted-proxy configuration.

## 4. Sign the APK (once)

Run on your computer, in any folder (keep the file and passwords safe; if you lose them you cannot update the installed app):

```bash
keytool -genkey -v -keystore blistra-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias blistra
```

Then print it as base64. On Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("blistra-release.jks")) | Set-Clipboard
```

## 5. GitHub (build the APK)

In the repository open **Settings → Secrets and variables → Actions**.

**Secrets**

| Name | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the base64 text from step 4 |
| `ANDROID_KEYSTORE_PASSWORD` | the keystore password you chose |
| `ANDROID_KEY_ALIAS` | `blistra` |
| `ANDROID_KEY_PASSWORD` | the key password (same as the keystore password if you pressed Enter) |

**Variables**: `API_BASE_URL` = your HTTPS API origin (no credentials, API path, query or fragment), and `SUPPORT_EMAIL` = a real monitored inbox. Both are required by the release job. The app also rejects missing/invalid release API configuration at startup.

Then open **Actions → Verify and release**. Only `main` publishes `Blistra APK <number>` after backend, frontend and real-client contract jobs pass. A missing signing secret fails the release; it does not substitute a debug key. Enable required checks in repository branch protection separately.

## 6. Install on your phone

1. On the phone open the repository's **Releases** page in the browser (you need to be signed in to GitHub if the repository is private) and download `blistra.apk`.
2. Open the file. Android asks to allow installing from your browser; allow it once.
3. Open Blistra, create an account, and enter the code from the email.

## 7. Shipping updates

Pushes and pull requests targeting `develop`/`main` run verification. Only `main` builds and publishes the signed APK as `apk-N`, with N stamped into the app. Verify that the backend deployment also waits for required checks.

Installed apps ask the backend (`GET /api/v1/app/latest`) for the newest `apk-N` release when Home opens. When it is newer than their own build they show **Update available**: **Update** downloads the APK and opens Android's installer (the user taps **Install**), **Later** hides it for a day. Users can also check in Profile > Help & support > Check for updates. Data stays on the server.

- Android never installs a sideloaded update silently; the user always confirms.
- The first time, Android asks to allow Blistra to install apps; allow it once.
- Every build must be signed with the same keystore, or Android refuses to install it over the old one.
- To force old installs to update (e.g. after a breaking API change), set `APP_MIN_SUPPORTED_BUILD=<N>` on Render. Builds below N get a prompt they can't dismiss.
- The backend reads releases from `APP_UPDATE_GITHUB_REPO` (default `sourabh2310/blistra`, which must be public). If GitHub rate limits ever bite, set `APP_UPDATE_GITHUB_TOKEN`.
- APKs built before this feature (builds 1–4) have no update check; install the next build by hand once.

## Limits to know about

- **Documents/photos** require the mounted persistent volume. Database backups alone do not include those bytes. Per-user documents are limited to 100 files / 100 MiB, with a 10-MiB per-file limit. File validation is not malware scanning; enable a scanning solution before opening uploads broadly.
- **Phone (SMS) verification** is off. Registration only needs the email code. Build with `--dart-define=REQUIRE_PHONE_VERIFICATION=true` and set `SMS_ENABLED=true` once an SMS provider exists.
- **Neon** pauses the database when idle and wakes it on the next request, so the first call after a long pause is slower.

## Backups, deletion and recovery

- Owner must define and publish backup frequency, retention, access and deletion service levels before launch; the app currently makes no fixed retention promise. Encrypt backups and restrict operators to the people who need access.
- Take coordinated PostgreSQL and file-volume backups, retaining relative UUID object keys unchanged. Include profiles/avatars as well as documents. Do not store backups in the same volume as the only live copy.
- Restore into an isolated environment: import a database snapshot, restore matching bytes, preserve file permissions, then run Flyway and readiness checks. Compare every document `stored_object_key` and profile `avatar_object_key` with the restored files; verify downloads and hashes using test accounts.
- Run deletion scenarios in staging: delete a file/account, confirm DB metadata disappears, make storage temporarily unavailable, restore access and check the persistent deletion queue drains. Interrupted uploads are reconciled after 24 hours; this grace period is not the backup retention policy.
- Test rollback by deploying the previous image against a restored snapshot in staging. For a production incident, stop writes, preserve evidence without logging health/finance content, then restore a matched database/file pair with operator approval. Record any recovery-point data loss and notify affected users through the owner's incident process.
- Perform and record a restore drill before launch and after storage/provider changes. A documented procedure without a successful restore is not evidence that backups work.

## Pilot acceptance

Use at least three disposable users and two overlapping trip groups. Verify invitations cannot read ledgers before acceptance, pending/rejected payments do not affect balances, only the other participant can confirm, and currencies/groups stay separate. Check logout/account switching, document opening/failure, optional-phone onboarding, timezone changes and notifications after Android reboot. Review linked policies and support contact. See `REMEDIATION_PROGRESS.md` for unresolved work.
