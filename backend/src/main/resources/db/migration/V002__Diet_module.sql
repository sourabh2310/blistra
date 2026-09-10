-- V002__Diet_module.sql
-- Diet module schema for Blistra backend.
--
-- Scope: diet profile / preferences, meals, meal items, and water intake.
-- All Diet resources are owned by a user (referenced by users.id).

-- ---------------------------------------------------------------------------
-- Diet profiles (optional, at most one per user)
-- ---------------------------------------------------------------------------
CREATE TABLE diet_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    dietary_preference VARCHAR(50),
    custom_preference VARCHAR(100),
    disliked_foods VARCHAR(1000),
    notes VARCHAR(2000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT diet_profiles_user_id_unique UNIQUE (user_id),
    CONSTRAINT diet_profiles_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT diet_profiles_preference_valid CHECK (
        dietary_preference IS NULL OR
        dietary_preference IN ('VEGETARIAN', 'VEGAN', 'NON_VEGETARIAN', 'PESCATARIAN', 'OTHER')
    ),
    CONSTRAINT diet_profiles_custom_for_other CHECK (
        dietary_preference <> 'OTHER' OR (custom_preference IS NOT NULL AND custom_preference <> '')
    )
);

CREATE INDEX idx_diet_profiles_user_id ON diet_profiles(user_id);

CREATE TRIGGER diet_profiles_updated_at_trigger
BEFORE UPDATE ON diet_profiles
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Meals (eating events)
-- ---------------------------------------------------------------------------
CREATE TABLE meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    meal_type VARCHAR(50) NOT NULL,
    title VARCHAR(200) NOT NULL,
    notes VARCHAR(2000),
    consumed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT meals_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT meals_type_valid CHECK (meal_type IN ('BREAKFAST', 'LUNCH', 'DINNER', 'SNACK', 'OTHER')),
    CONSTRAINT meals_title_not_empty CHECK (title <> '')
);

-- Frequently used scroll patterns: a user's history ordered by consumption time,
-- and a user's meals grouped by type.
CREATE INDEX idx_meals_user_consumed_at ON meals(user_id, consumed_at);
CREATE INDEX idx_meals_user_type ON meals(user_id, meal_type);

CREATE TRIGGER meals_updated_at_trigger
BEFORE UPDATE ON meals
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Meal items (a food item inside a meal)
-- ---------------------------------------------------------------------------
CREATE TABLE meal_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_id UUID NOT NULL,
    name VARCHAR(200) NOT NULL,
    quantity NUMERIC(12,3),
    unit VARCHAR(50),
    calories_kcal NUMERIC(10,2),
    protein_g NUMERIC(10,2),
    carbohydrates_g NUMERIC(10,2),
    fat_g NUMERIC(10,2),
    fiber_g NUMERIC(10,2),
    notes VARCHAR(1000),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT meal_items_meal_fk FOREIGN KEY (meal_id) REFERENCES meals(id) ON DELETE CASCADE,
    CONSTRAINT meal_items_name_not_empty CHECK (name <> ''),
    CONSTRAINT meal_items_quantity_positive CHECK (quantity IS NULL OR quantity > 0),
    CONSTRAINT meal_items_calories_nonnegative CHECK (calories_kcal IS NULL OR calories_kcal >= 0),
    CONSTRAINT meal_items_protein_nonnegative CHECK (protein_g IS NULL OR protein_g >= 0),
    CONSTRAINT meal_items_carbs_nonnegative CHECK (carbohydrates_g IS NULL OR carbohydrates_g >= 0),
    CONSTRAINT meal_items_fat_nonnegative CHECK (fat_g IS NULL OR fat_g >= 0),
    CONSTRAINT meal_items_fiber_nonnegative CHECK (fiber_g IS NULL OR fiber_g >= 0)
);

CREATE INDEX idx_meal_items_meal_id ON meal_items(meal_id);

CREATE TRIGGER meal_items_updated_at_trigger
BEFORE UPDATE ON meal_items
FOR EACH ROW EXECUTE FUNCTION update_timestamp();

-- ---------------------------------------------------------------------------
-- Water intake
-- ---------------------------------------------------------------------------
CREATE TABLE water_intake (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    amount NUMERIC(10,2) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    consumed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT water_intake_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT water_intake_amount_positive CHECK (amount > 0),
    CONSTRAINT water_intake_unit_valid CHECK (unit IN ('ml', 'mL', 'L', 'l', 'glass', 'glasses', 'cup', 'cups'))
);

CREATE INDEX idx_water_intake_user_consumed_at ON water_intake(user_id, consumed_at);

CREATE TRIGGER water_intake_updated_at_trigger
BEFORE UPDATE ON water_intake
FOR EACH ROW EXECUTE FUNCTION update_timestamp();