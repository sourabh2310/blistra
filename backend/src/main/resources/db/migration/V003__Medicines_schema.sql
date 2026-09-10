-- V003__Medicines_schema.sql
-- Medicines domain schema for Blistra backend.
--
-- This schema implements the personal medication tracker:
--   medicines            - medications tracked by a user
--   medication_schedules - scheduled dosing instructions for a medicine
--   dose_records         - actual dose events (taken / missed / skipped)
--   refills              - medicine refill information
--
-- Ownership model: every medicine belongs to exactly one user. Schedules,
-- dose records, and refills belong to a medicine, and transitively to its owner.
-- All ownership enforcement happens in the application layer (never trusted
-- from the client). Foreign keys and indexes below enforce referential
-- integrity and the access patterns used by the APIs.
--
-- History strategy: medicines are archived rather than hard-deleted so that
-- dose history and refill history remain meaningful. If a medicine is ever
-- hard-deleted, dose records and refills are cascade-removed with it because
-- they have no meaning without their parent medicine.

-- ---------------------------------------------------------------------------
-- medicines
-- ---------------------------------------------------------------------------
CREATE TABLE medicines (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    name            VARCHAR(100) NOT NULL,
    generic_name    VARCHAR(100),
    form            VARCHAR(50),
    strength        NUMERIC(12, 4),
    strength_unit   VARCHAR(25),
    notes           VARCHAR(1000),
    status          VARCHAR(25) NOT NULL DEFAULT 'ACTIVE',
    start_date      DATE,
    end_date        DATE,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT medicines_user_fk        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT medicines_name_not_empty CHECK (name <> ''),
    CONSTRAINT medicines_status_valid   CHECK (status IN ('ACTIVE', 'PAUSED', 'COMPLETED', 'ARCHIVED')),
    CONSTRAINT medicines_strength_nonnegative CHECK (strength IS NULL OR strength >= 0),
    CONSTRAINT medicines_dates_valid    CHECK (start_date IS NULL OR end_date IS NULL OR start_date <= end_date)
);

CREATE INDEX idx_medicines_user_id         ON medicines(user_id);
CREATE INDEX idx_medicines_user_status     ON medicines(user_id, status);

CREATE TRIGGER medicines_updated_at_trigger
BEFORE UPDATE ON medicines
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- medication_schedules
-- ---------------------------------------------------------------------------
CREATE TABLE medication_schedules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medicine_id     UUID NOT NULL,
    schedule_type   VARCHAR(25) NOT NULL,
    times           TEXT NOT NULL DEFAULT '',
    days_of_week    TEXT NOT NULL DEFAULT '',
    dose_amount     NUMERIC(12, 4),
    dose_unit       VARCHAR(25),
    start_date      DATE,
    end_date        DATE,
    active          BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT medication_schedules_medicine_fk
        FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE,
    CONSTRAINT medication_schedules_type_valid
        CHECK (schedule_type IN ('DAILY', 'WEEKLY', 'CUSTOM_DAYS', 'AS_NEEDED')),
    CONSTRAINT medication_schedules_dose_nonnegative
        CHECK (dose_amount IS NULL OR dose_amount >= 0),
    CONSTRAINT medication_schedules_dates_valid
        CHECK (start_date IS NULL OR end_date IS NULL OR start_date <= end_date)
);

CREATE INDEX idx_schedules_medicine_id ON medication_schedules(medicine_id);

CREATE TRIGGER medication_schedules_updated_at_trigger
BEFORE UPDATE ON medication_schedules
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- dose_records
-- ---------------------------------------------------------------------------
CREATE TABLE dose_records (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medicine_id     UUID NOT NULL,
    schedule_id     UUID,
    status          VARCHAR(25) NOT NULL,
    scheduled_at    TIMESTAMPTZ,
    taken_at        TIMESTAMPTZ,
    note            VARCHAR(500),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT dose_records_medicine_fk
        FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE,
    CONSTRAINT dose_records_schedule_fk
        FOREIGN KEY (schedule_id) REFERENCES medication_schedules(id) ON DELETE SET NULL,
    CONSTRAINT dose_records_status_valid
        CHECK (status IN ('TAKEN', 'MISSED', 'SKIPPED')),
    CONSTRAINT dose_records_taken_after_scheduled
        CHECK (taken_at IS NULL OR scheduled_at IS NULL OR taken_at >= scheduled_at)
);

CREATE INDEX idx_dose_records_medicine_scheduled ON dose_records(medicine_id, scheduled_at);
CREATE INDEX idx_dose_records_medicine_status    ON dose_records(medicine_id, status);

CREATE TRIGGER dose_records_updated_at_trigger
BEFORE UPDATE ON dose_records
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- refills
-- ---------------------------------------------------------------------------
CREATE TABLE refills (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    medicine_id         UUID NOT NULL,
    refill_date         DATE NOT NULL,
    quantity            NUMERIC(12, 4) NOT NULL,
    remaining_quantity  NUMERIC(12, 4),
    notes               VARCHAR(500),
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT refills_medicine_fk
        FOREIGN KEY (medicine_id) REFERENCES medicines(id) ON DELETE CASCADE,
    CONSTRAINT refills_quantity_positive      CHECK (quantity > 0),
    CONSTRAINT refills_remaining_nonnegative  CHECK (remaining_quantity IS NULL OR remaining_quantity >= 0)
);

CREATE INDEX idx_refills_medicine_date ON refills(medicine_id, refill_date);

CREATE TRIGGER refills_updated_at_trigger
BEFORE UPDATE ON refills
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();