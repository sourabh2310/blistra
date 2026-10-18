CREATE TABLE ai_entry_drafts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    entry_type VARCHAR(64) NOT NULL,
    payload TEXT NOT NULL,
    revision INTEGER NOT NULL DEFAULT 1,
    state VARCHAR(16) NOT NULL DEFAULT 'PENDING',
    result TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP + INTERVAL '30 minutes',
    CHECK (state IN ('PENDING', 'APPLIED', 'CANCELLED', 'SUPERSEDED'))
);
CREATE INDEX ai_entry_drafts_owner ON ai_entry_drafts(user_id, created_at DESC);
