-- Existing codes were delivered synchronously. New queued codes become usable
-- only after the provider accepts them. Plaintext never enters the outbox.
ALTER TABLE verification_otps ADD COLUMN delivered BOOLEAN NOT NULL DEFAULT TRUE;
CREATE TABLE otp_delivery_outbox (
    otp_id UUID PRIMARY KEY REFERENCES verification_otps(id) ON DELETE CASCADE,
    encrypted_code TEXT NOT NULL,
    attempts INTEGER NOT NULL DEFAULT 0,
    available_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    lease_token UUID,
    lease_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX otp_delivery_due ON otp_delivery_outbox(available_at);
