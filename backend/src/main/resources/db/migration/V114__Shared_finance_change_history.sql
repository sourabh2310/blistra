CREATE TABLE finance_change_history (
    id BIGSERIAL PRIMARY KEY,
    entity_id UUID NOT NULL,
    entity_type VARCHAR(16) NOT NULL,
    action VARCHAR(24) NOT NULL,
    actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
    group_id UUID REFERENCES finance_groups(id) ON DELETE SET NULL,
    audience UUID[] NOT NULL,
    before_amount NUMERIC(19,4),
    after_amount NUMERIC(19,4),
    currency VARCHAR(3) NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX finance_history_audience ON finance_change_history USING GIN(audience);
CREATE INDEX finance_history_group ON finance_change_history(group_id,recorded_at DESC);
