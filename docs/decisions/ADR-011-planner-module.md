# ADR-011 — Planner Module

## Status

Accepted

## Context

Blistra requires a personal planning module that lets users create tasks, organise them into lists, schedule simple time-blocked events, and view a consolidated "today" aggregation. This module must be owned entirely by the Planner domain — no duplication of health appointments, medication schedules, habit entries or other module data.

Key requirements:
- CRUD for tasks, task lists and events
- State machine for task status (TODO → IN_PROGRESS → COMPLETED/CANCELLED; COMPLETED can reopen; CANCELLED can reopen)
- User-facing due date/time stored as calendar fields; a derived `due_at` instant is resolved at write time in the configured user timezone
- Overdue is always derived, never stored
- "Today" view combines overdue tasks, tasks due today, and events overlapping today (Planner data only)
- Hard delete for tasks; deleting a task list unassigns its tasks
- No recurrence engine, no external calendar sync, no push notifications in V1
- Strict ownership enforcement (IDOR returns 404)

## Decision

The Planner module is implemented as a vertical slice in the modular monolith:

1. **Backend (Spring Boot 4.1.1, Java 21)**
   - Domain entities: `Task`, `TaskList`, `PlannerEvent` with JPA mapping and PostgreSQL UUID PKs
   - Repositories: ownership-scoped queries (`findByIdAndUserId`, `search`, `findOverlapping`)
   - Services: `PlannerTaskService`, `PlannerListService`, `PlannerEventService`, `PlannerTodayService`
   - Controllers: REST endpoints under `/api/v1/planner/{tasks,lists,events,today}` with OpenAPI annotations
   - Migration `V030__Planner_schema.sql` (tables `planner_task`, `planner_task_list`, `planner_event` with `user_id` FK `ON DELETE CASCADE`, check constraints, and per-table `update_timestamp` triggers)
   - Config property `planner.user-timezone` (default `Asia/Kolkata`) for interpreting calendar boundaries; per-user timezone is future work
   - Validation: `@NotBlank`, `@Size`, `@NotNull` on DTOs; invalid state transitions throw `InvalidStateException` → 409
   - Exceptions: `ResourceNotFoundException` (404 for cross-user access), `BadRequestException` (400), `InvalidStateException` (409)

2. **Frontend (Flutter 3.47, Dart 3.13)**
   - Minimal dependencies: `http` + `shared_preferences`
   - Core: `ApiClient` (timeout, Bearer token, `ApiException` mapping), `SessionStore`, `AuthToken`
   - Auth: `AuthController` (register/login/logout/restore), login & register screens
   - Planner state: `PlannerController` (ChangeNotifier) exposing tasks, lists, events, today view, filters and mutations
   - Screens: Today, Tasks (filter chips + list dropdown), Lists, Events; form screens for each
   - Widgets: `TaskCard`, `EventCard`, `ErrorRetry`, `EmptyState`
   - No hardcoded data; all real backend calls

## Alternatives Considered

| Alternative | Rejected Because |
|-------------|------------------|
| Full Calendar / iCal integration | Out of scope for V1; adds external dependency complexity |
| Recurrence rules (RRULE) | Significant domain complexity; can be added as a future enhancement |
| Per-user timezone in DB now | No user profile table exists yet; single global default is sufficient for MVP |
| Cross-module "today" aggregation | Explicitly out of scope per Planner ownership; dashboard phase handles this |
| Storing overdue as a column | Overdue is inherently time-sensitive and must recompute on read; storing it drifts |
| Soft delete tasks | Hard delete simplifies GDPR and avoids stale data; list delete unassigns tasks instead |

## Consequences

- **Benefits**: Clean domain boundary; testable state machine; timezone-correct calendar semantics; IDOR-safe; minimal dependencies; clear separation from Health/Medicines/Diet/Finance/Habits modules
- **Costs**: No recurrence, no push, no external sync — these must be designed separately if needed
- **Risks**: If the global timezone default doesn't match a user's actual zone, "today" and "overdue" boundaries shift; mitigated by documenting the config and planning per-user timezone as the next step

## Revisit Conditions

- A user profile with IANA timezone exists → migrate `planner.user-timezone` to per-user setting
- Recurrence requirements become concrete → evaluate RRULE library or custom engine
- Dashboard module needs Planner data → add read-only API or event stream for cross-module aggregation
- Push notifications are required → extend with FCM/APNs tokens and server-side scheduler