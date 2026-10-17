CREATE TABLE finance_groups (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users(id),
    name VARCHAR(120) NOT NULL CHECK (length(trim(name)) > 0),
    currency VARCHAR(3) NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE finance_group_members (
    group_id UUID NOT NULL REFERENCES finance_groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(16) NOT NULL CHECK (status IN ('INVITED','ACCEPTED')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(group_id, user_id)
);
CREATE INDEX finance_group_members_user ON finance_group_members(user_id, status);
ALTER TABLE finance_expenses ADD COLUMN group_id UUID REFERENCES finance_groups(id) ON DELETE SET NULL;
ALTER TABLE finance_settlements ADD COLUMN group_id UUID REFERENCES finance_groups(id) ON DELETE SET NULL;
CREATE INDEX finance_expenses_group ON finance_expenses(group_id, spent_on DESC);
CREATE INDEX finance_settlements_group ON finance_settlements(group_id, settled_on DESC);
