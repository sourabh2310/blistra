# Blistra — Architecture Decision Records

Architecture Decision Records (ADRs) document important technical and architectural decisions made during the development of Blistra.

The purpose of an ADR is to preserve:

- The decision
- The context
- The reasoning
- The alternatives considered
- The consequences

ADRs should focus on **why** a decision was made, not simply describe the resulting implementation.

---

## ADR Status

A decision may have one of these statuses:

- **Proposed** — Under discussion
- **Accepted** — Current decision
- **Superseded** — Replaced by a newer decision
- **Deprecated** — No longer applicable

---

## Current Decisions

The following decisions have been established for the initial Blistra architecture.

IDDecisionStatusADR-001Use a modular monolith for the initial backendAcceptedADR-002Use PostgreSQL as the primary relational databaseAcceptedADR-003Use Flutter for Android, iOS, and WebAcceptedADR-004Use Java 21 + Spring Boot for the backendAcceptedADR-005Use Maven Wrapper instead of requiring global MavenAcceptedADR-006Keep database timestamps in UTCAcceptedADR-007Enforce authorization and resource ownership server-sideAcceptedADR-008Keep AI behind controlled application toolsAcceptedADR-009Avoid premature distributed infrastructureAcceptedADR-010Notifications and Reminders PlatformAcceptedADR-011Planner ModuleAcceptedADR-012Health Module ArchitectureAcceptedADR-013Diet Domain & Nutrition BoundaryAcceptedADR-014Date/Time Handling in DietAcceptedADR-015Ownership & IDOR Protection ModelAcceptedADR-016Medicines Module: Personal Medication TrackingAccepted

---

## ADR Index

### ADR-001 — Modular Monolith

The initial backend is a modular monolith rather than a microservices architecture.

The application runs as one deployable Spring Boot application while maintaining explicit domain boundaries internally.

The decision can be revisited if measured requirements justify extracting specific components.

### ADR-002 — PostgreSQL

PostgreSQL is the primary relational database for Blistra.

The initial data model should favor explicit relational structures, constraints, relationships, and indexes.

### ADR-003 — Flutter

Flutter is the primary client technology for Android, iOS, and Web.

Android has the highest initial priority.

### ADR-004 — Java 21 and Spring Boot

The backend uses Java 21 and Spring Boot.

This provides the foundation for the REST API, validation, persistence, health endpoints, and future backend capabilities.

### ADR-005 — Maven Wrapper

The repository uses the Maven Wrapper.

Developers do not need a separately installed global Maven version to build the backend.

### ADR-006 — UTC Database Time

Database timestamps are handled consistently using UTC.

User-facing time is interpreted using the user's configured timezone.

The local development environment currently uses `Asia/Kolkata`.

### ADR-007 — Server-Side Authorization

Authorization and resource ownership are enforced by the backend.

The Flutter client is never considered a trusted authorization boundary.

### ADR-008 — Controlled AI Access

AI functionality operates through controlled application capabilities and tools.

AI must not receive unrestricted database or infrastructure access.

Health and medicine AI functionality must remain bounded and non-diagnostic.

### ADR-009 — Avoid Premature Distributed Infrastructure

Kafka, Kubernetes, microservices, and similar distributed infrastructure are not initial requirements.

They may be introduced later only when concrete scalability, reliability, or operational requirements justify them.

### ADR-010 — Notifications and Reminders Platform

Notifications is a delivery mechanism, not the owner of business events.

Reminders store an absolute instant plus the user's IANA timezone; only GENERAL reminders are client-created, while domain reminders are owned by their module.

Initial delivery is client-side local scheduling, with device-token storage prepared for a future push provider.

See [ADR-010-notifications-and-reminders-platform.md](./ADR-010-notifications-and-reminders-platform.md).

### ADR-011 — Planner Module

Planner module architecture and implementation.

See [ADR-011-planner-module.md](./ADR-011-planner-module.md).

### ADR-012 — Health Module Architecture

A personal health tracking module covering profile, measurements (weight, height, heart rate, temperature, blood pressure), sleep records, activity, health observation logs, generic health events, and appointments.

Backend: dedicated `health` Spring module (`com.blistra.health`) with seven Flyway-managed tables, per-type unit/range validation, and strict user-scoped ownership via `CurrentUserProvider`. REST endpoints under `/api/v1/health/*` return `PageResponse<T>` envelopes; profile is a singleton per user (upsert via PUT).

Frontend: Flutter feature `lib/features/health/` with typed models (enum `wire` values matching backend), `HealthApi` (thin `ApiClient` wrapper), `HealthRepository` (`ChangeNotifier` cache with auto-refresh), and generic `RecordListScreen<T>` + `FormScaffold` for seven resource UIs. Auth via shared `AuthController` + `SessionStore` (shared_preferences).

Privacy: no logging of health data in backend or frontend; `GlobalExceptionHandler` logs only path + error code.

See [ADR-012-health-module.md](./ADR-012-health-module.md).

### ADR-013 — Diet Domain & Nutrition Boundary

The Diet module owns four tables: `diet_profiles`, `meals`, `meal_items`, `water_intake`. Allergies/intolerances remain in Health. Nutrition fields are optional; totals sum only explicitly recorded values (null when none). Water total only counts ml/L units.

See [ADR-013-diet-domain-nutrition-boundary.md](./ADR-013-diet-domain-nutrition-boundary.md).

### ADR-014 — Date/Time Handling in Diet

All timestamps stored as `TIMESTAMPTZ` (`OffsetDateTime`). Day boundaries defined by client-sent `date` + `offsetMinutes`. No server-local time. Client computes offset from device timezone.

See [ADR-014-diet-date-time-handling.md](./ADR-014-diet-date-time-handling.md).

### ADR-015 — Ownership & IDOR Protection Model

All queries scoped to authenticated user's UUID via `BlistraUserPrincipal`. Cross-user access returns 404 (not 403). Items protected via meal ownership. Frontend never sends userId. 401 triggers logout.

See [ADR-015-diet-ownership-idor-protection.md](./ADR-015-diet-ownership-idor-protection.md).

### ADR-016 — Medicines Module: Personal Medication Tracking

A personal medication tracking module covering medicines, schedules, dose events, and refill history. All data is user-recorded; no medical advice or auto-marking of missed doses.

Backend: dedicated `medicines` Spring module with four Flyway-managed tables, `TIMESTAMPTZ` timestamps, schedule recurrence via enum + wire arrays, soft-delete archive strategy. REST endpoints under `/api/v1/medicines/*` return `PageResponse<T>` envelopes; all queries scoped via `CurrentUserProvider`.

Frontend: Flutter feature `lib/features/medicines/` with typed models (enum `wire` values matching backend), `MedicinesApiClient` (thin `http.Client` wrapper), `ChangeNotifier` state controllers, and screens for list, forms, detail (quick dose recording), and history. Auth via shared `AuthState` + `ApiClient`.

See [ADR-016-medicines-module.md](./ADR-016-medicines-module.md).

---

## Creating New ADRs

When a significant architectural decision is made, create a new file using the next sequential ID.

Example:

```
docs/decisions/ADR-010-example-decision.md
```

Recommended structure:

```
# ADR-010 — Decision Title

## Status

Accepted

## Context

What problem or requirement led to this decision?

## Decision

What are we deciding?

## Alternatives Considered

What reasonable alternatives were considered?

## Consequences

What are the benefits, costs, risks, and trade-offs?

## Revisit Conditions

Under what circumstances should this decision be reconsidered?
```

---

## ADR Guidelines

Create an ADR when a decision:

- Affects system architecture
- Establishes a long-term technology choice
- Changes module boundaries
- Changes data ownership
- Introduces significant infrastructure
- Changes security boundaries
- Changes AI capabilities or permissions
- Has meaningful operational consequences

Do not create an ADR for every implementation detail.

ADRs should remain concise enough to be useful while preserving the reasoning behind important decisions.