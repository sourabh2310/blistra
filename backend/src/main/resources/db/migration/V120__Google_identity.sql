-- Google sign-in: the stable Google account id ("sub" claim) linked to a user.
ALTER TABLE users ADD COLUMN google_sub VARCHAR(64);

CREATE UNIQUE INDEX users_google_sub_unique
    ON users (google_sub)
    WHERE google_sub IS NOT NULL;
