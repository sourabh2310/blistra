# Pilot operations and launch decisions

Updated 2026-10-18. Intended operating country: **India**, as confirmed by the owner. Operator/legal identity, monitored support inbox and backup retention are **undecided**. These are deployment proposals, not an active service commitment or a statement of legal compliance.

## Backup proposal

The selected deployment is the existing Neon database and a Render Free web service. New documents and avatars use PostgreSQL BYTEA storage, with a 64-MiB aggregate logical upload cap. No paid Render disk is required. Historic files already lost from temporary container storage still need re-uploading or restoration from an existing file backup.

Start a small pilot with **one database backup daily, retained for 14 days**, and a **restore exercise every month**. These are proposals requiring an operator and backup destination, not configured Neon retention. Proposed recovery objectives are at most 24 hours of lost records and a four-hour restoration target. Measure a restore before promising either. Verify the actual Neon plan's recovery window separately; do not assume it provides fourteen days.

In PostgreSQL storage mode, a custom-format `pg_dump -Fc` includes metadata and binary objects in one consistent database snapshot, without pausing application writes. See the official [pg_dump documentation](https://www.postgresql.org/docs/current/app-pgdump.html). Record UTC times, application commit and migration version. Use protected PostgreSQL service/password files rather than credentials in arguments or logs. No production backup has been run by this work.

For the optional filesystem backend only, pause application writes and file-deletion/reconciliation workers, then take a matched database dump and file-volume copy from that write-free interval, including upload markers and a SHA-256 manifest. Resume only after completion. A database-only backup cannot restore filesystem-mode bytes.

Encrypt backups and keep a protected copy outside the application's host. Restrict access to the chosen operator and keep encryption keys in a separate secret store. Include recoverable JWT, OTP pepper and OTP delivery key versions in that secret store. Budget for fourteen compressed daily copies, measure actual growth and agree deletion requirements before finalizing retention. Provider recovery history and retained backups can still contain deleted data until their retention expires.

Restore into a separate database (and empty volume for filesystem mode), never over the live service. Run readiness, login, document download, avatar, trip balance and pending/confirmed-payment checks with disposable accounts. Replay applicable deletion requests before reopening restored data. Record elapsed time, missing bytes and manual steps; successful `pg_restore` alone is insufficient evidence of an application restore.

## Monitoring

Set a separate random `BLISTRA_METRICS_TOKEN` of at least 32 characters in the operator's secret store. With no token, `/internal/metrics` returns 404. Send the token in `X-Blistra-Metrics-Token` over HTTPS from the monitoring collector. A user JWT grants no metrics access. Restrict collector ingress at the host when available, redact this header from proxy logs, and rotate it after exposure. Do not place the token in a URL or committed scrape configuration.

The endpoint exports Prometheus metrics for JVM memory, HTTP rates/latency and sampled OTP/file-deletion queues. Queue gauges are sampled every 60 seconds; the sample timestamp detects a stalled sampler. Storage metrics expose aggregate bytes and the configured budget. Host free-disk bytes are exported only for filesystem storage and do not measure Neon capacity. Historical filesystem deletion-queue rows remain for operator reconciliation; PostgreSQL objects are deleted transactionally. Delivery attempt/exhaustion counters contain no destinations or account identifiers. [monitoring-alerts.yml](monitoring-alerts.yml) supplies initial alert rules. Validate them with `promtool check rules` on the chosen collector and route alerts only after a responsible operator and contact are selected. No collector or notification destination has been provisioned.

Initial thresholds are proposals: OTP queue older than two minutes, deletion backlog older than one hour, upload budget over 80%, filesystem-mode volume free space below 100 MiB, API errors over 5% with sufficient request volume, and p95 latency over two seconds. Tune them using pilot measurements. The API's public readiness endpoint remains separate and exposes no diagnostic details.

On a delivery incident, inspect SMTP configuration/provider status and queue age/attempts. The worker retries the same encrypted code at most five times; repeated restarts do not make a provider outage disappear. On storage pressure, stop new uploads, verify the deletion worker, expand approved capacity or apply the agreed retention policy; never remove shared records or referenced bytes ad hoc. On database outage, restore connectivity and verify readiness before reopening traffic. Perform these exercises in staging before the pilot.

Render Free sleeps after inactivity, so startup latency and background delivery pauses must be included in pilot expectations. Pending database-backed deliveries resume when the service wakes; do not promise continuous worker availability. Check [Render free instance limitations](https://render.com/docs/free), including supported outbound SMTP ports.

## Capacity and proxy settings

PostgreSQL storage defaults to a **64 MiB** aggregate document/avatar budget (`DOCUMENTS_MAX_TOTAL_BYTES=67108864`). The budget measures object bytes, excluding database indexes, WAL, retained history and backups; monitor actual project usage in Neon separately. Capacity checks serialize through a PostgreSQL transaction lock across instances and join the metadata transaction. Optional filesystem storage defaults to **800 MiB**, a **50 MiB** volume reserve and a 20,000-directory-entry safety ceiling; measure directory-scan latency before scaling that backend. A bounded capacity rejection returns `503 STORAGE_CAPACITY`; existing records remain readable and deletable.

Authentication budgets are 100 requests per source and 20 logins per account per fixed 15-minute window, plus a configurable aggregate default of 1,000 auth requests per window (`BLISTRA_AUTH_GLOBAL_MAXIMUM`). These protect application work; edge request-body, connection and traffic limits are still required at the actual host. Global limits can affect all users during an attack, so monitor rejected traffic and tune from measured demand.

By default the socket peer is the client address. Only set `BLISTRA_TRUSTED_PROXIES` to the actual ingress proxy IP/CIDR ranges after verifying that direct access is blocked and the ingress appends/overwrites forwarding headers correctly. The application walks `X-Forwarded-For` from right to left until the first untrusted hop. Malformed chains and headers from untrusted peers are ignored. Never configure `0.0.0.0/0` or `::/0` as a shortcut. Keep framework automatic forwarding disabled so another layer does not bypass this trust boundary.

## Still required before a public launch

- Choose the operating identity, support owner/inbox, final retention and incident responsibilities. Review policies for the chosen Indian operation and actual providers; country selection does not settle legal requirements.
- Preserve available historic bytes and test a restore before rollout. Configure `BLISTRA_OTP_DELIVERY_KEY` and select PostgreSQL storage before deploying. V118 adds database objects; it cannot reconstruct lost files. No live migration or restart has been performed by this work.
- Configure stable signing and branch protection, then install/update the signed APK on physical devices. Exercise native timezone changes, document/export save dialogs, reboot/permissions and the rolling offline reminder horizon.
- Implement and validate isolated content inspection/malware scanning before treating uploads as safe documents. Current MIME checks and size/capacity budgets do not establish that a PDF/image is harmless. Full decoder isolation and client image downsampling remain engineering work.
- Complete lifecycle/finance load tests on the intended host. Expense changes are still creator-controlled with visible history; settlements require the other participant. Any expense dispute/approval workflow needs a separate product decision.

## Pilot and business validation

Suggested initial audience: three small groups of three to five adults organizing trips in India. Start with INR and one real trip per group; test overlapping membership and an additional currency with disposable records. Keep the first pilot focused on shared expenses and payments, while describing medicine reminders as a supplementary feature with a rolling offline horizon. No users have been recruited or contacted by this work.

Ask pilot participants to register/verify, create and decline invitations, split an expense three ways, change a split, inspect history, reject a mistaken payment, confirm a real recorded payment, archive/reopen, export and leave/rejoin. Compare balances against a manually calculated ledger. Include slow/offline access, denied notifications, account switching, large text and a reboot. A payment confirmation records participant agreement; it is not independent evidence of a bank transfer.

Suggested acceptance criteria: every tested ledger matches manual calculations; pending/rejected payments never affect balances; no cross-account/group data exposure; participants can explain who owes what and recover from a mistaken entry. Record onboarding completion and time-to-first-shared-expense manually with participant consent. Do not add tracking or session recordings merely to satisfy a metric. Use observed failures to prioritize the remaining dispute, accessibility and background-renewal work.

Before pricing, measure monthly fixed hosting/database costs and per-active-user document bytes, backup copies, SMTP volume and support minutes. A simple worksheet is `(fixed compute + database + storage + backups + email + support) / monthly active users`. Estimate both a small pilot and ten times its demand; include retained backups and failed/retried deliveries. No price, margin or operating-cost promise has been set. Assign a monitored support inbox and incident owner before inviting anyone outside the pilot.

## Dependency maintenance

CI pins actions to official release commits, fixes the runner image to Ubuntu 24.04, runs strict Flutter analysis, packages a CycloneDX backend SBOM at `META-INF/sbom/application.cdx.json`, and preserves a Flutter dependency inventory. Weekly Dependabot configuration covers Actions, Maven, Dart and the container base image. Review upgrade PRs and advisories with their test results; inventories do not by themselves certify that dependencies are vulnerability-free. Action versions were resolved from the official [checkout](https://github.com/actions/checkout), [setup-java](https://github.com/actions/setup-java), [flutter-action](https://github.com/subosito/flutter-action), [upload-artifact](https://github.com/actions/upload-artifact) and [release-action](https://github.com/softprops/action-gh-release) repositories. SBOM generation uses the official [CycloneDX Maven plugin](https://github.com/CycloneDX/cyclonedx-maven-plugin).
