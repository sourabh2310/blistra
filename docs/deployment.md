# Deploying Blistra for free and testing the APK on your phone

Stack: **Neon** (Postgres) + **Render** (backend container) + **Brevo** (verification email) + **GitHub Actions** (builds the APK). Everything below has a free tier.

Do the steps in order. Keep a text file open and paste each value into it as you get it.

## 1. Neon (database)

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

1. Sign up at brevo.com (free plan, about 300 emails a day).
2. **Senders, Domains & Dedicated IPs → Senders → Add a sender.** Use an email address you own (a Gmail address works) and confirm the email Brevo sends you.
3. **SMTP & API → SMTP.** Copy the **Login** (looks like `a1b2c3@smtp-brevo.com`) and generate an **SMTP key**.

| Render variable | Value |
|---|---|
| `MAIL_USERNAME` | the Brevo SMTP login |
| `MAIL_PASSWORD` | the SMTP key |
| `MAIL_FROM` | the sender address you verified |

## 3. Render (backend)

1. Sign up at render.com with your GitHub account.
2. **New → Blueprint**, pick the `blistra` repository and the `develop` branch. Render reads `render.yaml` and proposes a service called `blistra-api` on the **Free** plan.
3. Fill in the variables it asks for: `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `MAIL_USERNAME`, `MAIL_PASSWORD`, `MAIL_FROM`. `JWT_SECRET` and `BLISTRA_OTP_PEPPER` are generated for you.
4. Press **Apply**. The first build takes about 5 minutes.
5. When it is live, open `https://<your-service>.onrender.com/health`. You should see `{"status":"UP"}`. That URL (without `/health`) is your **API URL**.

The free plan sleeps after 15 minutes without traffic, so the first request after a pause takes 30 to 60 seconds. To avoid that, create a free monitor at uptimerobot.com that requests `https://<your-service>.onrender.com/health` every 5 minutes.

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

**Variables** tab → `API_BASE_URL` = your Render URL, for example `https://blistra-api.onrender.com` (no trailing slash).

Then open **Actions → Build Android APK → Run workflow**. After a few minutes the APK is attached to a new release named `Blistra APK <number>`.

## 6. Install on your phone

1. On the phone open the repository's **Releases** page in the browser (you need to be signed in to GitHub if the repository is private) and download `blistra.apk`.
2. Open the file. Android asks to allow installing from your browser; allow it once.
3. Open Blistra, create an account, and enter the code from the email.

To ship an update, push to `develop` (or run the workflow again) and install the new APK over the old one. Your data stays on the server.

## Limits to know about

- **Documents** are stored on the server's disk, which Render wipes on every restart and redeploy. Treat uploads as temporary until we move them to object storage.
- **Phone (SMS) verification** is off. Registration only needs the email code. Build with `--dart-define=REQUIRE_PHONE_VERIFICATION=true` and set `SMS_ENABLED=true` once an SMS provider exists.
- **Neon** pauses the database when idle and wakes it on the next request, so the first call after a long pause is slower.
