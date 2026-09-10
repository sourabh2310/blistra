-- V100__Finance_schema.sql
-- Finance domain schema for Blistra backend.
--
-- Financial data is highly sensitive and always belongs to exactly one user.
-- Money is stored as NUMERIC(19,4) (precision 19, scale 4); amounts are always
-- non-negative and the financial direction is expressed by the record type
-- (INCOME / EXPENSE / transfer direction), never by amount sign.
-- Currency is explicit (ISO 4217, uppercase) on every financial row.
--
-- Deleting financial history is deliberately NOT cascaded from users: losing a
-- user's accounts must never silently destroy transaction history.

-- ---------------------------------------------------------------------------
-- Accounts
-- ---------------------------------------------------------------------------
CREATE TABLE finance_accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    opening_balance NUMERIC(19,4) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    notes VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finance_accounts_user_fk FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT finance_accounts_name_not_empty CHECK (name <> ''),
    CONSTRAINT finance_accounts_type_valid
        CHECK (type IN ('CASH', 'BANK', 'SAVINGS', 'CREDIT_CARD', 'WALLET', 'OTHER')),
    CONSTRAINT finance_accounts_status_valid
        CHECK (status IN ('ACTIVE', 'ARCHIVED')),
    CONSTRAINT finance_accounts_currency_valid
        CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT finance_accounts_opening_balance_not_negative
        CHECK (opening_balance >= 0)
);

CREATE INDEX idx_finance_accounts_user_id ON finance_accounts(user_id);

CREATE TRIGGER finance_accounts_updated_at_trigger
BEFORE UPDATE ON finance_accounts
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Categories
-- ---------------------------------------------------------------------------
CREATE TABLE finance_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finance_categories_user_fk FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT finance_categories_name_not_empty CHECK (name <> ''),
    CONSTRAINT finance_categories_type_valid
        CHECK (type IN ('INCOME', 'EXPENSE')),
    CONSTRAINT finance_categories_status_valid
        CHECK (status IN ('ACTIVE', 'ARCHIVED'))
);

CREATE INDEX idx_finance_categories_user_id ON finance_categories(user_id);

CREATE TRIGGER finance_categories_updated_at_trigger
BEFORE UPDATE ON finance_categories
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Transactions (income and expense financial events)
-- ---------------------------------------------------------------------------
CREATE TABLE finance_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    account_id UUID NOT NULL,
    category_id UUID NOT NULL,
    type VARCHAR(20) NOT NULL,
    amount NUMERIC(19,4) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    occurred_at DATE NOT NULL,
    description VARCHAR(255),
    notes VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finance_transactions_user_fk FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT finance_transactions_account_fk FOREIGN KEY (account_id) REFERENCES finance_accounts(id),
    CONSTRAINT finance_transactions_category_fk FOREIGN KEY (category_id) REFERENCES finance_categories(id),
    CONSTRAINT finance_transactions_type_valid
        CHECK (type IN ('INCOME', 'EXPENSE')),
    CONSTRAINT finance_transactions_currency_valid
        CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT finance_transactions_amount_positive
        CHECK (amount > 0)
);

CREATE INDEX idx_finance_transactions_user_id
    ON finance_transactions(user_id, occurred_at);
CREATE INDEX idx_finance_transactions_account_id
    ON finance_transactions(account_id, occurred_at);
CREATE INDEX idx_finance_transactions_category_id
    ON finance_transactions(category_id, occurred_at);
CREATE INDEX idx_finance_transactions_user_type
    ON finance_transactions(user_id, type, occurred_at);

CREATE TRIGGER finance_transactions_updated_at_trigger
BEFORE UPDATE ON finance_transactions
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Transfers (movement between two accounts belonging to the same user)
-- ---------------------------------------------------------------------------
-- A transfer is a first-class record so money movement is not misreported as
-- an expense plus an income, which would double-count it.
CREATE TABLE finance_transfers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    source_account_id UUID NOT NULL,
    destination_account_id UUID NOT NULL,
    amount NUMERIC(19,4) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    transferred_at DATE NOT NULL,
    note VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT finance_transfers_user_fk FOREIGN KEY (user_id) REFERENCES users(id),
    CONSTRAINT finance_transfers_source_fk FOREIGN KEY (source_account_id) REFERENCES finance_accounts(id),
    CONSTRAINT finance_transfers_destination_fk FOREIGN KEY (destination_account_id) REFERENCES finance_accounts(id),
    CONSTRAINT finance_transfers_currency_valid
        CHECK (currency ~ '^[A-Z]{3}$'),
    CONSTRAINT finance_transfers_amount_positive
        CHECK (amount > 0),
    CONSTRAINT finance_transfers_distinct_accounts
        CHECK (source_account_id <> destination_account_id)
);

CREATE INDEX idx_finance_transfers_user_id
    ON finance_transfers(user_id, transferred_at);
CREATE INDEX idx_finance_transfers_source_account_id
    ON finance_transfers(source_account_id, transferred_at);
CREATE INDEX idx_finance_transfers_destination_account_id
    ON finance_transfers(destination_account_id, transferred_at);

CREATE TRIGGER finance_transfers_updated_at_trigger
BEFORE UPDATE ON finance_transfers
FOR EACH ROW EXECUTE FUNCTION update_timestamp();