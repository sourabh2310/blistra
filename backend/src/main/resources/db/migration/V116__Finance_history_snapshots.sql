-- Historical amounts cannot reconstruct old splits. Leave those snapshots NULL.
ALTER TABLE finance_change_history ADD COLUMN before_state JSONB;
ALTER TABLE finance_change_history ADD COLUMN after_state JSONB;
CREATE INDEX finance_history_group_order ON finance_change_history(group_id,recorded_at DESC,id DESC);
CREATE INDEX finance_settlements_group_order ON finance_settlements(group_id,created_at DESC,id DESC);
