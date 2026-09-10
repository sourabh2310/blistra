-- V004__Health_schema.sql
-- Health module schema for Blistra backend.
--
-- Scope: health profile, measurements, sleep records, activities, symptom
-- logs, health events, and appointments.
--
-- Ownership model: every Health resource belongs to exactly one user
-- (referenced by users.id). All ownership enforcement happens in the
-- application layer; foreign keys and indexes below enforce referential
-- integrity and the access patterns used by the APIs.
--
-- Time model: audit fields (created_at / updated_at) are TIMESTAMP and follow
-- the existing update_timestamp() trigger convention. User-supplied moments
-- (measured_at, started_at/ended_at, performed_at, observed_at, occurred_at,
-- scheduled_at) are TIMESTAMPTZ because they carry an explicit offset.
--
-- Measurements: a single table for all measurement types. BLOOD_PRESSURE uses
-- value (systolic) + value_diastolic; other types use value only. Units are
-- stored uppercase and constrained per type.

-- ---------------------------------------------------------------------------
-- Health profiles (optional, at most one per user)
-- ---------------------------------------------------------------------------
CREATE TABLE health_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    height_cm NUMERIC(5,2),
    blood_type VARCHAR(20),
    date_of_birth DATE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT health_profiles_user_id_unique UNIQUE (user_id),
    CONSTRAINT health_profiles_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT health_profiles_height_valid CHECK (height_cm IS NULL OR height_cm > 0),
    CONSTRAINT health_profiles_blood_type_valid CHECK (
        blood_type IS NULL OR
        blood_type IN ('A_POSITIVE', 'A_NEGATIVE', 'B_POSITIVE', 'B_NEGATIVE',
                       'AB_POSITIVE', 'AB_NEGATIVE', 'O_POSITIVE', 'O_NEGATIVE', 'UNKNOWN')
    )
);

CREATE TRIGGER health_profiles_updated_at_trigger
BEFORE UPDATE ON health_profiles
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Health measurements
-- ---------------------------------------------------------------------------
CREATE TABLE health_measurements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(20) NOT NULL,
    measured_at TIMESTAMPTZ NOT NULL,
    value NUMERIC(10,2) NOT NULL,
    value_diastolic NUMERIC(10,2),
    unit VARCHAR(10) NOT NULL,
    source VARCHAR(50),
    notes VARCHAR(500),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT health_measurements_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT health_measurements_type_valid CHECK (
        type IN ('WEIGHT', 'HEIGHT', 'HEART_RATE', 'TEMPERATURE', 'BLOOD_PRESSURE')
    ),
    CONSTRAINT health_measurements_value_positive CHECK (value > 0),
    CONSTRAINT health_measurements_diastolic_positive CHECK (value_diastolic IS NULL OR value_diastolic > 0),
    CONSTRAINT health_measurements_unit_valid CHECK (
        (type = 'WEIGHT' AND unit IN ('KG', 'LB')) OR
        (type = 'HEIGHT' AND unit IN ('CM', 'IN')) OR
        (type = 'HEART_RATE' AND unit = 'BPM') OR
        (type = 'TEMPERATURE' AND unit IN ('C', 'F')) OR
        (type = 'BLOOD_PRESSURE' AND unit = 'MMHG')
    ),
    CONSTRAINT health_measurements_pressure_consistent CHECK (
        (type = 'BLOOD_PRESSURE' AND value_diastolic IS NOT NULL AND value > value_diastolic) OR
        (type <> 'BLOOD_PRESSURE' AND value_diastolic IS NULL)
    )
);

-- Common scroll pattern: a user's measurement history ordered by measured time.
CREATE INDEX idx_health_measurements_user_measured_at ON health_measurements(user_id, measured_at);

CREATE TRIGGER health_measurements_updated_at_trigger
BEFORE UPDATE ON health_measurements
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Sleep records (duration derived from started_at / ended_at)
-- ---------------------------------------------------------------------------
CREATE TABLE health_sleep_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ NOT NULL,
    rating INTEGER,
    notes VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT health_sleep_records_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT health_sleep_records_time_order_valid CHECK (ended_at > started_at),
    CONSTRAINT health_sleep_records_rating_valid CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5))
);

CREATE INDEX idx_health_sleep_records_user_started_at ON health_sleep_records(user_id, started_at);

CREATE TRIGGER health_sleep_records_updated_at_trigger
BEFORE UPDATE ON health_sleep_records
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Activities
-- ---------------------------------------------------------------------------
CREATE TABLE health_activities (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(30) NOT NULL,
    performed_at TIMESTAMPTZ NOT NULL,
    duration_minutes INTEGER NOT NULL,
    distance_km NUMERIC(8,2),
    calories_burned INTEGER,
    notes VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT health_activities_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT health_activities_type_valid CHECK (
        type IN ('WALKING', 'RUNNING', 'CYCLING', 'SWIMMING',
                 'STRENGTH_TRAINING', 'YOGA', 'SPORTS', 'OTHER')
    ),
    CONSTRAINT health_activities_duration_positive CHECK (duration_minutes >= 1),
    CONSTRAINT health_activities_distance_nonnegative CHECK (distance_km IS NULL OR distance_km >= 0),
    CONSTRAINT health_activities_calories_nonnegative CHECK (calories_burned IS NULL OR calories_burned >= 0)
);

CREATE INDEX idx_health_activities_user_performed_at ON health_activities(user_id, performed_at);

CREATE TRIGGER health_activities_updated_at_trigger
BEFORE UPDATE ON health_activities
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Symptom logs (personal observations, never a diagnosis)
-- ---------------------------------------------------------------------------
CREATE TABLE health_symptom_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title VARCHAR(120) NOT NULL,
    description VARCHAR(1000),
    observed_at TIMESTAMPTZ NOT NULL,
    severity VARCHAR(20),
    notes VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT health_symptom_logs_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT health_symptom_logs_title_not_empty CHECK (title <> ''),
    CONSTRAINT health_symptom_logs_severity_valid CHECK (
        severity IS NULL OR severity IN ('MILD', 'MODERATE', 'SEVERE')
    )
);

CREATE INDEX idx_health_symptom_logs_user_observed_at ON health_symptom_logs(user_id, observed_at);

CREATE TRIGGER health_symptom_logs_updated_at_trigger
BEFORE UPDATE ON health_symptom_logs
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Health events (check-up, vaccination, medical visit, lab test, other)
-- ---------------------------------------------------------------------------
CREATE TABLE health_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    type VARCHAR(30) NOT NULL,
    title VARCHAR(200) NOT NULL,
    occurred_at TIMESTAMPTZ NOT NULL,
    notes VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT health_events_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT health_events_type_valid CHECK (
        type IN ('CHECKUP', 'VACCINATION', 'MEDICAL_VISIT', 'LAB_TEST', 'OTHER')
    ),
    CONSTRAINT health_events_title_not_empty CHECK (title <> '')
);

CREATE INDEX idx_health_events_user_occurred_at ON health_events(user_id, occurred_at);

CREATE TRIGGER health_events_updated_at_trigger
BEFORE UPDATE ON health_events
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Appointments
-- ---------------------------------------------------------------------------
CREATE TABLE health_appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    title VARCHAR(200) NOT NULL,
    scheduled_at TIMESTAMPTZ NOT NULL,
    location VARCHAR(200),
    notes VARCHAR(1000),
    status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT health_appointments_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT health_appointments_title_not_empty CHECK (title <> ''),
    CONSTRAINT health_appointments_status_valid CHECK (
        status IN ('SCHEDULED', 'CONFIRMED', 'COMPLETED', 'CANCELLED', 'MISSED')
    )
);

CREATE INDEX idx_health_appointments_user_scheduled_at ON health_appointments(user_id, scheduled_at);

CREATE TRIGGER health_appointments_updated_at_trigger
BEFORE UPDATE ON health_appointments
FOR EACH ROW EXECUTE FUNCTION update_timestamp();