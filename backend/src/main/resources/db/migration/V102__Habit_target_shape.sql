-- Habit target-shape integrity (same-table row CHECKs only).
--
-- Mirrors the service/DTO validation:
--   BOOLEAN : target_value/unit/minutes all NULL
--   COUNT   : target_value > 0, target_unit present, target_minutes NULL
--   DURATION: target_minutes > 0, target_value/unit NULL
--
-- Added NOT VALID so the migration never fails on pre-existing rows;
-- it is enforced for all new/updated rows. Run
--   ALTER TABLE habits VALIDATE CONSTRAINT <name>;
-- after backfilling legacy data.

ALTER TABLE habits
    ADD CONSTRAINT habits_target_shape_valid CHECK (
        (type = 'BOOLEAN' AND target_value IS NULL AND target_unit IS NULL AND target_minutes IS NULL)
        OR (type = 'COUNT' AND target_value IS NOT NULL AND target_value > 0
            AND target_unit IS NOT NULL AND target_minutes IS NULL)
        OR (type = 'DURATION' AND target_minutes IS NOT NULL AND target_minutes > 0
            AND target_value IS NULL AND target_unit IS NULL)
    ) NOT VALID;
