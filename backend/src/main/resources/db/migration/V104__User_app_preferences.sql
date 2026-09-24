-- V104 user app preferences (Home widgets + bottom navigation).
--
-- One row per user, owned server-side via the authenticated principal; the
-- client never supplies a user id. Values are canonical comma-separated
-- identifier lists validated in the service layer against the allowlists in
-- AppPreferencesService (unknown identifiers are rejected, never stored).

CREATE TABLE IF NOT EXISTS user_app_preferences (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    bottom_nav TEXT NOT NULL DEFAULT 'HOME,PLANNER,ADD,HEALTH,HUB',
    home_widgets TEXT NOT NULL DEFAULT 'DAY_AT_A_GLANCE,HEALTH,MEDICINES,DIET,HABITS,PLANNER,FINANCE',
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
