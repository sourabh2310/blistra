-- Small-pilot storage for stateless/free application hosts. Bytes and owning
-- metadata commit in the same PostgreSQL transaction; no local disk required.
CREATE TABLE document_objects (
    object_key VARCHAR(36) PRIMARY KEY,
    content BYTEA NOT NULL,
    byte_count BIGINT NOT NULL CHECK (byte_count >= 0 AND byte_count <= 10485760 AND byte_count = octet_length(content)),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
