-- Profile hub: photo, short bio, gender, emergency contact and the
-- "who can add me" privacy switch. All optional; existing rows keep working.
ALTER TABLE user_profiles
    ADD COLUMN avatar_object_key          VARCHAR(64),
    ADD COLUMN avatar_content_type        VARCHAR(32),
    ADD COLUMN avatar_updated_at          TIMESTAMP,
    ADD COLUMN bio                        VARCHAR(280),
    ADD COLUMN gender                     VARCHAR(24),
    ADD COLUMN emergency_contact_name     VARCHAR(120),
    ADD COLUMN emergency_contact_phone    VARCHAR(32),
    ADD COLUMN emergency_contact_relation VARCHAR(40),
    ADD COLUMN allow_friend_requests      BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE user_profiles
    ADD CONSTRAINT user_profiles_gender_check CHECK (
        gender IS NULL OR gender IN ('FEMALE', 'MALE', 'NON_BINARY', 'PREFER_NOT_TO_SAY'));
