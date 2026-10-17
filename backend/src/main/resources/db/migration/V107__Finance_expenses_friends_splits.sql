-- V107__Finance_expenses_friends_splits.sql
-- Finance is reshaped around everyday expense logging and splitting costs
-- with friends (by username):
--
--   * finance_friendships     - request/accept link between two users
--   * finance_expenses        - one spend, paid by one user, split into shares
--   * finance_expense_shares  - how much of an expense each participant owes
--   * finance_settlements     - "settle up" payments between two friends
--   * finance_budgets         - optional monthly spending limits
--
-- Money follows the V100 conventions: NUMERIC(19,4), never negative,
-- explicit ISO 4217 currency on every row. Shared history is never cascaded
-- from users (it belongs to more than one person).

CREATE TABLE finance_friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    addressee_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finance_friendships_status_valid CHECK (status IN ('PENDING', 'ACCEPTED')),
    CONSTRAINT finance_friendships_distinct_users CHECK (requester_id <> addressee_id)
);

-- One link per unordered pair of users.
CREATE UNIQUE INDEX finance_friendships_pair_unique
    ON finance_friendships (LEAST(requester_id, addressee_id), GREATEST(requester_id, addressee_id));
CREATE INDEX idx_finance_friendships_requester ON finance_friendships(requester_id);
CREATE INDEX idx_finance_friendships_addressee ON finance_friendships(addressee_id);

CREATE TRIGGER finance_friendships_updated_at_trigger
BEFORE UPDATE ON finance_friendships
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE finance_expenses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by UUID NOT NULL REFERENCES users(id),
    paid_by UUID NOT NULL REFERENCES users(id),
    description VARCHAR(255) NOT NULL,
    category VARCHAR(30) NOT NULL,
    amount NUMERIC(19,4) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    spent_on DATE NOT NULL,
    split_type VARCHAR(20) NOT NULL,
    notes VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finance_expenses_description_not_empty CHECK (description <> ''),
    CONSTRAINT finance_expenses_amount_positive CHECK (amount > 0),
    CONSTRAINT finance_expenses_currency_valid CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT finance_expenses_split_type_valid
        CHECK (split_type IN ('NONE', 'EQUAL', 'EXACT', 'PERCENT', 'SHARES')),
    CONSTRAINT finance_expenses_category_valid CHECK (category IN (
        'FOOD', 'GROCERIES', 'TRANSPORT', 'FUEL', 'SHOPPING', 'BILLS', 'RENT',
        'ENTERTAINMENT', 'TRAVEL', 'HEALTH', 'EDUCATION', 'GIFTS',
        'PERSONAL_CARE', 'SUBSCRIPTIONS', 'OTHER'))
);

CREATE INDEX idx_finance_expenses_paid_by ON finance_expenses(paid_by, spent_on);
CREATE INDEX idx_finance_expenses_created_by ON finance_expenses(created_by, spent_on);

CREATE TRIGGER finance_expenses_updated_at_trigger
BEFORE UPDATE ON finance_expenses
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE finance_expense_shares (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    expense_id UUID NOT NULL REFERENCES finance_expenses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    amount NUMERIC(19,4) NOT NULL,
    -- The raw split input (percentage or share weight) so edits round-trip.
    input_value NUMERIC(19,4),
    CONSTRAINT finance_expense_shares_amount_not_negative CHECK (amount >= 0),
    CONSTRAINT finance_expense_shares_unique UNIQUE (expense_id, user_id)
);

CREATE INDEX idx_finance_expense_shares_user ON finance_expense_shares(user_id);

CREATE TABLE finance_settlements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by UUID NOT NULL REFERENCES users(id),
    payer_id UUID NOT NULL REFERENCES users(id),
    payee_id UUID NOT NULL REFERENCES users(id),
    amount NUMERIC(19,4) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    settled_on DATE NOT NULL,
    note VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finance_settlements_amount_positive CHECK (amount > 0),
    CONSTRAINT finance_settlements_currency_valid CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT finance_settlements_distinct_users CHECK (payer_id <> payee_id)
);

CREATE INDEX idx_finance_settlements_payer ON finance_settlements(payer_id, settled_on);
CREATE INDEX idx_finance_settlements_payee ON finance_settlements(payee_id, settled_on);

CREATE TRIGGER finance_settlements_updated_at_trigger
BEFORE UPDATE ON finance_settlements
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

CREATE TABLE finance_budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- NULL category = overall monthly budget.
    category VARCHAR(30),
    currency VARCHAR(3) NOT NULL,
    monthly_limit NUMERIC(19,4) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finance_budgets_limit_positive CHECK (monthly_limit > 0),
    CONSTRAINT finance_budgets_currency_valid CHECK (currency ~ '^[A-Z]{3}$')
);

CREATE UNIQUE INDEX finance_budgets_scope_unique
    ON finance_budgets (user_id, COALESCE(category, 'ALL'), currency);

CREATE TRIGGER finance_budgets_updated_at_trigger
BEFORE UPDATE ON finance_budgets
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- Carry existing expense transactions over as personal expenses so nobody
-- loses history; the legacy tables are left untouched.
WITH migrated AS (
    INSERT INTO finance_expenses (id, created_by, paid_by, description, category, amount,
                                  currency, spent_on, split_type, notes, created_at, updated_at)
    SELECT t.id, t.user_id, t.user_id,
           COALESCE(NULLIF(trim(t.description), ''), c.name),
           CASE
               WHEN lower(c.name) ~ 'grocer'                        THEN 'GROCERIES'
               WHEN lower(c.name) ~ 'food|dining|restaurant|meal|cafe' THEN 'FOOD'
               WHEN lower(c.name) ~ 'fuel|petrol|gas'               THEN 'FUEL'
               WHEN lower(c.name) ~ 'transport|travel cab|taxi|uber|bus|metro|train' THEN 'TRANSPORT'
               WHEN lower(c.name) ~ 'rent'                          THEN 'RENT'
               WHEN lower(c.name) ~ 'bill|utilit|electric|internet|phone' THEN 'BILLS'
               WHEN lower(c.name) ~ 'shop|cloth'                    THEN 'SHOPPING'
               WHEN lower(c.name) ~ 'movie|entertain|fun'           THEN 'ENTERTAINMENT'
               WHEN lower(c.name) ~ 'travel|trip|hotel|flight'      THEN 'TRAVEL'
               WHEN lower(c.name) ~ 'health|medic|doctor|pharma'    THEN 'HEALTH'
               WHEN lower(c.name) ~ 'educat|course|book|school'     THEN 'EDUCATION'
               WHEN lower(c.name) ~ 'gift'                          THEN 'GIFTS'
               WHEN lower(c.name) ~ 'subscri|netflix|spotify'       THEN 'SUBSCRIPTIONS'
               ELSE 'OTHER'
           END,
           t.amount, t.currency, t.occurred_at, 'NONE', t.notes, t.created_at, t.updated_at
      FROM finance_transactions t
      JOIN finance_categories c ON c.id = t.category_id
     WHERE t.type = 'EXPENSE'
    RETURNING id, created_by, amount
)
INSERT INTO finance_expense_shares (expense_id, user_id, amount)
SELECT id, created_by, amount FROM migrated;
