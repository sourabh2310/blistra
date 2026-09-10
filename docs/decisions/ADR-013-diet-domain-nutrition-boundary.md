# ADR-013: Diet Domain & Nutrition Boundary

## Status
Accepted

## Context
The Diet module must own a clear, self-contained set of entities without leaking into Health/Medicines/Habits modules. The requirement explicitly states: "Allergies and intolerances are Health domain; do not reimplement here." Nutrition data must be a pure recording of explicitly entered values, not a computation engine or medical assessment.

## Decision
The Diet module owns exactly four tables:
- `diet_profiles` — non-medical dietary preferences (VEGETARIAN, VEGAN, NON_VEGETARIAN, PESCATARIAN, OTHER + custom label when OTHER).
- `meals` — eating events with type (BREAKFAST, LUNCH, DINNER, SNACK, OTHER), title, optional notes, and a consumption timestamp.
- `meal_items` — food items belonging to a meal; each item stores name, quantity, unit, and optional nutrition facts (calories, protein, carbohydrates, fat, fiber in g/kcal). All nutrition fields are nullable.
- `water_intake` — hydration records with amount, unit (ml/L/glass/cup), and consumption timestamp.

**Nutrition recording rules:**
- A meal item may have any subset of the six nutrition fields (calories, protein, carbs, fat, fiber). Missing values are *not* treated as zero — they are simply absent.
- Daily totals sum only explicitly recorded values. If no items record a field, the total is `null` (represented by `MacroTotalsResponse.total = null` plus a `recordedItems` count).
- `waterTotalMilliliters` is computed only from entries whose unit is a millilitre/litre value (`ml`, `mL`, `L`, `l`). Descriptor units (`glass`, `cups`) are recorded but contribute zero to the total.
- The frontend reflects the same semantics: no default values, no zero-filling, and explicit "not recorded" UI when totals are null.

**Health boundary:**
- No allergy, intolerance, medication, or medical condition fields exist in Diet. Those remain strictly in the Health module (to be implemented separately).
- `dietary_preference` is a lifestyle taxonomy, not a medical classification.

## Consequences
- The data model stays small and auditable.
- Backend and frontend can implement nutrition totals identically (sum of non-null values).
- Future Health module can link to Diet via `user_id` without schema entanglement.
- Clients must handle `null` totals gracefully (UI shows "—" or "not recorded").