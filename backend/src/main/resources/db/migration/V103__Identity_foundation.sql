-- V1 identity/authentication/profile foundation.
--
-- Extends users with username / phone / verification state / onboarding state
-- plus pending identity-change columns, and adds verification_otps and
-- user_profiles tables. All new uniqueness is enforced in the database;
-- lookups are case-insensitive via lower() indexes.

-- ---------------------------------------------------------------- users ---

ALTER TABLE users
    ADD COLUMN IF NOT EXISTS username VARCHAR(50),
    ADD COLUMN IF NOT EXISTS phone VARCHAR(32),
    ADD COLUMN IF NOT EXISTS email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS pending_email VARCHAR(255),
    ADD COLUMN IF NOT EXISTS pending_phone VARCHAR(32),
    ADD COLUMN IF NOT EXISTS terms_accepted_at TIMESTAMP;

-- Normalize legacy emails (the service lowercases on write).
UPDATE users SET email = lower(trim(email)) WHERE email <> lower(trim(email));

-- Backfill usernames from the email local part for pre-V103 rows:
-- strip characters outside the username alphabet, fall back to user_<id>
-- when fewer than 3 characters remain, then de-duplicate with a suffix.
WITH base AS (
    SELECT id,
           NULLIF(regexp_replace(lower(split_part(email, '@', 1)), '[^a-z0-9_.]', '', 'g'), '') AS raw,
           created_at
      FROM users
     WHERE username IS NULL
),
fixed AS (
    SELECT id,
           CASE WHEN raw IS NULL OR char_length(raw) < 3
                THEN 'user_' || substr(id::text, 1, 8)
                ELSE substr(raw, 1, 30)
           END AS name,
           created_at
      FROM base
),
ranked AS (
    SELECT id, name,
           ROW_NUMBER() OVER (PARTITION BY name ORDER BY created_at, id) AS rn
      FROM fixed
)
UPDATE users u
   SET username = CASE WHEN r.rn = 1 THEN r.name ELSE substr(r.name, 1, 27) || '_' || r.rn END
  FROM ranked r
 WHERE u.id = r.id;

ALTER TABLE users ALTER COLUMN username SET NOT NULL;

-- Case-insensitive uniqueness for username and email (service normalizes too).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'users_username_ci_unique') THEN
        CREATE UNIQUE INDEX users_username_ci_unique ON users (lower(username));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'users_email_ci_unique') THEN
        CREATE UNIQUE INDEX users_email_ci_unique ON users (lower(email));
    END IF;
END $$;

-- Phone is optional (legacy rows) but unique when present, E.164 canonical.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_phone_unique') THEN
        ALTER TABLE users ADD CONSTRAINT users_phone_unique UNIQUE (phone);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_phone_format') THEN
        ALTER TABLE users ADD CONSTRAINT users_phone_format
            CHECK (phone IS NULL OR phone ~ '^\+[1-9][0-9]{6,14}$');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_pending_email_format') THEN
        ALTER TABLE users ADD CONSTRAINT users_pending_email_format
            CHECK (pending_email IS NULL OR pending_email <> '');
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'users_pending_phone_format') THEN
        ALTER TABLE users ADD CONSTRAINT users_pending_phone_format
            CHECK (pending_phone IS NULL OR pending_phone ~ '^\+[1-9][0-9]{6,14}$');
    END IF;
END $$;

-- Allow the new PENDING_VERIFICATION lifecycle state.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_status_valid;
ALTER TABLE users ADD CONSTRAINT users_status_valid
    CHECK (status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED', 'PENDING_VERIFICATION'));

-- ---------------------------------------------------- verification_otps ---

CREATE TABLE IF NOT EXISTS verification_otps (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    purpose VARCHAR(32) NOT NULL,
    channel VARCHAR(16) NOT NULL,
    destination VARCHAR(255) NOT NULL,
    code_hash VARCHAR(128) NOT NULL,
    -- Development-only plaintext copy, written ONLY when blistra.otp.dev-mode
    -- is enabled. Always NULL in production rows.
    dev_code VARCHAR(8),
    expires_at TIMESTAMP NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    max_attempts INTEGER NOT NULL DEFAULT 5,
    consumed BOOLEAN NOT NULL DEFAULT FALSE,
    consumed_at TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT verification_otps_purpose_valid CHECK (purpose IN (
        'EMAIL_VERIFY', 'PHONE_VERIFY', 'PASSWORD_RESET',
        'EMAIL_CHANGE', 'PHONE_CHANGE')),
    CONSTRAINT verification_otps_channel_valid CHECK (channel IN ('EMAIL', 'SMS'))
);

CREATE INDEX IF NOT EXISTS idx_verification_otps_user ON verification_otps (user_id);
CREATE INDEX IF NOT EXISTS idx_verification_otps_lookup
    ON verification_otps (user_id, purpose, consumed, expires_at);

-- ------------------------------------------------------- user_profiles ---

CREATE TABLE IF NOT EXISTS user_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    display_name VARCHAR(120),
    date_of_birth DATE,
    country VARCHAR(2),
    timezone VARCHAR(64),
    language VARCHAR(16),
    unit_system VARCHAR(16),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT user_profiles_unit_valid CHECK (unit_system IS NULL OR unit_system IN ('METRIC', 'IMPERIAL'))
);

CREATE INDEX IF NOT EXISTS idx_user_profiles_user ON user_profiles (user_id);
