-- V003__Documents_schema.sql
-- Documents / Personal Records domain schema for Blistra backend.
--
-- This schema implements a private document vault where users can upload
-- and manage personal files (medical reports, prescriptions, invoices, etc.).
--
-- Ownership model: every document belongs to exactly one user.
-- Binary content is stored externally; this table stores metadata only.

CREATE TABLE documents (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID NOT NULL,
    original_filename       VARCHAR(255) NOT NULL,
    stored_object_key       VARCHAR(255) NOT NULL,
    content_type            VARCHAR(100) NOT NULL,
    file_size               BIGINT NOT NULL,
    content_hash            VARCHAR(64) NOT NULL,
    category                VARCHAR(30) NOT NULL,
    description             VARCHAR(1000),
    created_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT documents_user_fk            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT documents_filename_not_empty CHECK (original_filename <> ''),
    CONSTRAINT documents_object_key_not_empty CHECK (stored_object_key <> ''),
    CONSTRAINT documents_file_size_nonneg   CHECK (file_size >= 0),
    CONSTRAINT documents_category_valid     CHECK (category IN ('MEDICAL','FINANCE','PERSONAL','INSURANCE','RECEIPT','PRESCRIPTION','REPORT','OTHER')),
    CONSTRAINT documents_hash_not_empty     CHECK (content_hash <> '')
);

CREATE UNIQUE INDEX idx_documents_object_key ON documents(stored_object_key);
CREATE INDEX idx_documents_user_id ON documents(user_id);
CREATE INDEX idx_documents_user_created ON documents(user_id, created_at DESC);
CREATE INDEX idx_documents_user_category ON documents(user_id, category);

CREATE TRIGGER documents_updated_at_trigger
BEFORE UPDATE ON documents
FOR EACH ROW
EXECUTE FUNCTION update_timestamp();