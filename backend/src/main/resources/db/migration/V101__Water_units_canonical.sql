-- Canonical water-intake units + removal of the redundant diet-profile index.
--
-- Existing rows keep their meaning; only the spelling is normalized:
--   ml/mL -> ML, L/l -> L, glass/glasses -> GLASS, cup/cups -> CUP
-- New writes use the canonical set (see WaterUnit).

UPDATE water_intake SET unit = 'ML' WHERE unit IN ('ml', 'mL');
UPDATE water_intake SET unit = 'L' WHERE unit IN ('L', 'l');
UPDATE water_intake SET unit = 'GLASS' WHERE unit IN ('glass', 'glasses');
UPDATE water_intake SET unit = 'CUP' WHERE unit IN ('cup', 'cups');

ALTER TABLE water_intake DROP CONSTRAINT IF EXISTS water_intake_unit_valid;
ALTER TABLE water_intake
    ADD CONSTRAINT water_intake_unit_valid CHECK (unit IN ('ML', 'L', 'GLASS', 'CUP'));

-- UNIQUE(user_id) on diet_profiles already provides the needed index;
-- the extra explicit index is redundant.
DROP INDEX IF EXISTS idx_diet_profiles_user_id;
