# ADR-015: Ownership & IDOR Protection Model

## Status
Accepted

## Context
Every Diet resource belongs to a single user. The backend must enforce that users can only read, modify, or delete their own data. The frontend must never send a `user_id`; ownership is derived from the authenticated principal (JWT subject → email → user UUID via `BlistraUserPrincipal`).

## Decision
### Backend enforcement
- **User scoping:** All repository queries include `user_id` in the WHERE clause (`findByIdAndUserId`, `listByUserId`, `listByUserIdAndDate`). No query ever runs without an owning `user_id`.
- **Cross-user access:** Returns `404 Not Found` (`RESOURCE_NOT_FOUND`) instead of `403 Forbidden`. This prevents user enumeration and leaks no information about resource existence.
- **Item ownership:** Meal items are protected transitively: `mealService.addItem/updateItem/deleteItem` first verify the meal belongs to the user, then operate on the item. The repository for items has `findByIdAndMealId` — items are never looked up by item ID alone.
- **Cascades:** Deleting a meal cascades to its items (JPA `cascade = ALL, orphanRemoval = true` + DB `ON DELETE CASCADE`). Water records are hard-deleted.
- **Profile:** Single-row upsert per user (`diet_profiles.user_id` has a unique constraint). No list endpoint.

### Authentication principal
- Added `BlistraUserPrincipal` in `com.blistra.auth.security` carrying the authenticated user's UUID `id`. `CustomUserDetailsService` returns this principal. `AuthenticatedUser` (in `diet.application`) resolves the current user from `SecurityContextHolder`, with an email-lookup fallback for robustness.

### Frontend behaviour
- No `userId` field in any request body or query parameter.
- On any `401` (`AUTHENTICATION_REQUIRED`) the app clears the stored token and returns to the login screen.
- On `404` from a Diet endpoint, the UI treats it as "not found or access denied" — no special handling needed.

## Consequences
- Strong isolation: a compromised token cannot access another user's meals or water records.
- No IDOR surface: endpoints use UUIDs, but ownership checks make guessing another user's ID harmless.
- Consistent error code (`RESOURCE_NOT_FOUND`) across meal, item, water, and profile endpoints.
- The frontend stays simple: it never constructs user-scoped URLs; it just calls the API and reacts to 401/404.