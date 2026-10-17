CREATE TABLE authentication_rate_limits (
    bucket_key VARCHAR(64) NOT NULL,
    window_start BIGINT NOT NULL,
    hits INTEGER NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (bucket_key, window_start)
);
CREATE INDEX authentication_rate_limits_expiry ON authentication_rate_limits(expires_at);
