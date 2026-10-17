-- Existing recorded settlements keep their historical effect. New entries
-- are explicitly PENDING until the other participant confirms them.
ALTER TABLE finance_settlements ADD COLUMN status VARCHAR(16) NOT NULL DEFAULT 'LEGACY_RECORDED';
ALTER TABLE finance_settlements ALTER COLUMN status SET DEFAULT 'PENDING';
ALTER TABLE finance_settlements ADD COLUMN decided_at TIMESTAMPTZ;
ALTER TABLE finance_settlements ADD CONSTRAINT finance_settlement_status_valid
    CHECK (status IN ('PENDING', 'CONFIRMED', 'REJECTED', 'LEGACY_RECORDED'));
