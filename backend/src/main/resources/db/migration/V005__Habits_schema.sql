-- V005__Habits_schema.sql
-- Habits module schema for Blistra backend.
--
-- Scope: habit definitions, their recurring schedules, and daily completion
-- records used to derive streaks and history.
--
-- Ownership model: every habit belongs to exactly one user (referenced by
-- users.id). Schedules and completions belong to a habit and transitively to
-- its owner. All ownership enforcement happens in the application layer
-- (never trusted from the client). Foreign keys and indexes below enforce
-- referential integrity and the access patterns used by the APIs.
--
-- Habit type model (type):
--   BOOLEAN - a simple done/not-done habit with no target amount
--   COUNT   - quantified habit (e.g. glasses of water); target_value + target_unit
--   DURATION- time-based habit (e.g. meditation); target_minutes
--
-- Lifecycle (status): ACTIVE, PAUSED, ARCHIVED. Habits are archived rather
-- than hard-deleted so their completion history remains meaningful.

-- ---------------------------------------------------------------------------
-- habits
-- ---------------------------------------------------------------------------
CREATE TABLE habits (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    name            VARCHAR(100) NOT NULL,
    description     VARCHAR(500),
    type            VARCHAR(20) NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    target_value    NUMERIC(12, 4),
    target_unit     VARCHAR(25),
    target_minutes  INTEGER,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT habits_user_fk
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT habits_name_not_empty CHECK (name <> ''),
    CONSTRAINT habits_type_valid
        CHECK (type IN ('BOOLEAN', 'COUNT', 'DURATION')),
    CONSTRAINT habits_status_valid
        CHECK (status IN ('ACTIVE', 'PAUSED', 'ARCHIVED')),
    CONSTRAINT habits_target_value_nonnegative
        CHECK (target_value IS NULL OR target_value >= 0),
    CONSTRAINT habits_target_minutes_positive
        CHECK (target_minutes IS NULL OR target_minutes >= 1)
);

CREATE INDEX idx_habits_user_id      ON habits(user_id);
CREATE INDEX idx_habits_user_status  ON habits(user_id, status);

CREATE TRIGGER habits_updated_at_trigger
BEFORE UPDATE ON habits
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- habit_schedules
-- ---------------------------------------------------------------------------
CREATE TABLE habit_schedules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    habit_id        UUID NOT NULL,
    frequency       VARCHAR(20) NOT NULL,
    days_of_week    TEXT NOT NULL DEFAULT '',
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT habit_schedules_habit_fk
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
    CONSTRAINT habit_schedules_frequency_valid
        CHECK (frequency IN ('DAILY', 'WEEKLY'))
);

CREATE UNIQUE INDEX uk_habit_schedules_habit ON habit_schedules(habit_id);

CREATE TRIGGER habit_schedules_updated_at_trigger
BEFORE UPDATE ON habit_schedules
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- habit_completions
-- ---------------------------------------------------------------------------
CREATE TABLE habit_completions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    habit_id        UUID NOT NULL,
    completed_on    DATE NOT NULL,
    value           NUMERIC(12, 4),
    duration_minutes INTEGER,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT habit_completions_habit_fk
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
    CONSTRAINT uk_habit_completions_habit_date UNIQUE (habit_id, completed_on),
    CONSTRAINT habit_completions_value_nonnegative
        CHECK (value IS NULL OR value >= 0),
    CONSTRAINT habit_completions_duration_positive
        CHECK (duration_minutes IS NULL OR duration_minutes >= 1)
);

CREATE INDEX idx_habit_completions_habit_date ON habit_completions(habit_id, completed_on);

CREATE TRIGGER habit_completions_updated_at_trigger
BEFORE UPDATE ON habit_completions
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();