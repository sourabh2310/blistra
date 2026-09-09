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

IDDecisionStatusADR-001Use a modular monolith for the initial backendAcceptedADR-002Use PostgreSQL as the primary relational databaseAcceptedADR-003Use Flutter for Android, iOS, and WebAcceptedADR-004Use Java 21 + Spring Boot for the backendAcceptedADR-005Use Maven Wrapper instead of requiring global MavenAcceptedADR-006Keep database timestamps in UTCAcceptedADR-007Enforce authorization and resource ownership server-sideAcceptedADR-008Keep AI behind controlled application toolsAcceptedADR-009Avoid premature distributed infrastructureAccepted

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
