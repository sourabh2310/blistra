-- V010__Notifications_schema.sql
-- Notifications / Reminders platform schema for Blistra backend.
--
-- Notifications is a DELIVERY mechanism, not the owner of the underlying
-- business event. Medicine owns medication schedules, Habits owns recurrence,
-- Planner owns tasks/events, and Health owns appointments. This schema only
-- stores how/when a user should be reminded plus a soft reference back to the
-- owning domain record (source_id). source_id intentionally has NO foreign key
-- because the target table is polymorphic by reminder type; referential
-- integrity to the owning module is enforced in its own application layer.
--
-- Ownership model: every reminder and device registration belongs to exactly
-- one user. Ownership is always derived from the authenticated security
-- context, never accepted from the client.

-- ---------------------------------------------------------------------------
-- notification_preferences
-- ---------------------------------------------------------------------------
CREATE TABLE notification_preferences (
    user_id                UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    enabled                BOOLEAN NOT NULL DEFAULT TRUE,
    medicine_enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    habit_enabled          BOOLEAN NOT NULL DEFAULT TRUE,
    planner_enabled        BOOLEAN NOT NULL DEFAULT TRUE,
    health_enabled         BOOLEAN NOT NULL DEFAULT TRUE,
    general_enabled        BOOLEAN NOT NULL DEFAULT TRUE,
    hide_sensitive_content BOOLEAN NOT NULL DEFAULT FALSE,
    created_at             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TRIGGER notification_preferences_updated_at_trigger
BEFORE UPDATE ON notification_preferences
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- reminders
-- ---------------------------------------------------------------------------
CREATE TABLE reminders (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type         VARCHAR(20) NOT NULL,
    title        VARCHAR(160) NOT NULL,
    body         VARCHAR(500),
    scheduled_at TIMESTAMPTZ NOT NULL,
    timezone     VARCHAR(64) NOT NULL,
    status       VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
    source_id    UUID,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT reminders_type_valid CHECK (type IN ('MEDICINE', 'HABIT', 'PLANNER', 'HEALTH', 'GENERAL')),
    CONSTRAINT reminders_status_valid CHECK (status IN ('SCHEDULED', 'CANCELLED')),
    CONSTRAINT reminders_source_reference_consistency CHECK (
        (type = 'GENERAL' AND source_id IS NULL)
        OR (type <> 'GENERAL' AND source_id IS NOT NULL)
    ),
    CONSTRAINT reminders_title_not_empty CHECK (title <> ''),
    CONSTRAINT reminders_timezone_not_empty CHECK (timezone <> '')
);

CREATE INDEX idx_reminders_user_scheduled ON reminders(user_id, scheduled_at);
CREATE INDEX idx_reminders_user_status ON reminders(user_id, status);

CREATE TRIGGER reminders_updated_at_trigger
BEFORE UPDATE ON reminders
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- device_registrations
-- ---------------------------------------------------------------------------
-- Push tokens are treated as sensitive credentials: they are never returned by
-- any API and must not be logged.
CREATE TABLE device_registrations (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id     VARCHAR(255) NOT NULL,
    push_token    VARCHAR(512) NOT NULL,
    platform      VARCHAR(20) NOT NULL,
    active        BOOLEAN NOT NULL DEFAULT TRUE,
    created_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen_at  TIMESTAMP,
    CONSTRAINT device_registrations_user_device_unique UNIQUE (user_id, device_id),
    CONSTRAINT device_registrations_platform_valid CHECK (platform IN ('ANDROID', 'IOS', 'WEB')),
    CONSTRAINT device_registrations_device_id_not_empty CHECK (device_id <> ''),
    CONSTRAINT device_registrations_push_token_not_empty CHECK (push_token <> '')
);

CREATE INDEX idx_device_registrations_user ON device_registrations(user_id);

CREATE TRIGGER device_registrations_updated_at_trigger
BEFORE UPDATE ON device_registrations
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();