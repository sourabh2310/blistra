# Blistra — Architecture Overview

## 1. Architectural Goal

Blistra is designed as a secure, maintainable, mobile-first personal life-management platform.

The initial architecture prioritizes:

- Clear domain boundaries
- Strong data ownership
- Security
- Testability
- Maintainability
- Simple deployment
- Incremental evolution

The system should avoid premature distributed-system complexity.

## 2. High-Level Architecture

```text
                    ┌─────────────────────────┐
                    │     Flutter Clients     │
                    │                         │
                    │ Android / iOS / Web     │
                    └────────────┬────────────┘
                                 │
                              HTTPS
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │    Spring Boot API      │
                    │    Modular Monolith      │
                    │                         │
                    │ ┌───────┐ ┌───────────┐ │
                    │ │ Auth  │ │ Planner   │ │
                    │ ├───────┤ ├───────────┤ │
                    │ │Health │ │ Medicines │ │
                    │ ├───────┤ ├───────────┤ │
                    │ │ Diet  │ │ Habits    │ │
                    │ ├───────┤ ├───────────┤ │
                    │ │Finance│ │ Documents │ │
                    │ ├───────┤ ├───────────┤ │
                    │ │ AI    │ │ Notifs    │ │
                    │ └───────┘ └───────────┘ │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │       PostgreSQL        │
                    │      Primary Store      │
                    └─────────────────────────┘
```

## 3. Client Architecture

The frontend uses Flutter and Dart.

Target platforms:

- Android
- iOS
- Web

Android is the highest-priority platform.

The frontend should use a feature-oriented structure rather than organizing the entire application around generic technical layers.

Each feature should own its presentation, state, models, and relevant application logic.

The frontend communicates with the backend through HTTP APIs.

The client must not be trusted with authorization decisions.

## 4. Backend Architecture

The backend uses:

- Java 21
- Spring Boot
- Maven Wrapper
- Spring Web
- Spring Data JPA
- PostgreSQL
- Bean Validation
- Actuator

The backend is a **modular monolith**.

This means all initial backend modules run inside one deployable Spring Boot application while maintaining explicit internal boundaries.

The architecture is intentionally not based on microservices.

## 5. Domain Modules

Initial domain boundaries include:

- Users / Authentication
- Planner
- Health
- Medicines
- Diet
- Habits
- Finance
- Dashboard

Additional modules may be introduced later:

- Documents
- Notifications
- Goals
- AI

Each domain owns its own data and business rules.

For example:

- Health owns health records.
- Medicines owns medication records and medication-related rules.
- Finance owns financial records.
- Planner owns planning concepts and orchestration.

The Planner may reference or display information from other domains, but it should not become the owner of that domain's data.

## 6. Module Interaction

Modules should communicate through explicit application/domain interfaces rather than reaching directly into another module's persistence implementation.

Preferred direction:

```
Module A
   │
   ▼
Public application interface
   │
   ▼
Module B
```

Avoid:

```
Module A
   │
   ├──> Module B repository
   ├──> Module B entity
   └──> Module B database implementation
```

This keeps the modular monolith capable of evolving into more independent components later if there is a real need.

## 7. API Architecture

External clients communicate with versioned REST APIs.

Base path:

```
/api/v1
```

APIs should use:

- DTOs
- Request validation
- Explicit response models
- Consistent error responses
- Pagination where appropriate
- Filtering and sorting where appropriate
- Resource ownership checks
- OpenAPI documentation

Persistence entities should not be exposed directly as public API contracts.

## 8. Data Architecture

PostgreSQL is the primary relational database.

The data model should favor explicit relational structures over storing core business data as large JSON documents.

Important principles:

- Every user-owned resource must have clear ownership.
- Foreign-key relationships should enforce integrity.
- Important business invariants should be enforced by the database where appropriate.
- Frequently queried columns should have appropriate indexes.
- Created/updated timestamps should be consistent.
- Database migrations should be version controlled.

## 9. Time and Timezones

Persistence and application logic should use a consistent timezone strategy.

Database timestamps should be treated in UTC.

User-facing time should be converted using the user's configured timezone.

The current development environment uses:

```
Asia/Kolkata
```

as the local development/user timezone.

This should not be hard-coded as the permanent timezone for every Blistra user.

A future user profile should contain an appropriate timezone setting.

## 10. Security Architecture

Security is enforced primarily by the backend.

The basic request flow is:

```
Authentication
      ↓
Authorization
      ↓
Resource Ownership
      ↓
Business Rules
      ↓
Operation
```

The frontend may hide UI actions, but it must never be considered an authorization boundary.

Every protected resource must be checked against the authenticated user.

Secrets must not be committed to Git.

Logs should avoid exposing sensitive personal information.

## 11. AI Architecture

AI is an application capability, not an unrestricted database interface.

The intended future structure is:

```
User
  │
  ▼
Flutter
  │
  ▼
Backend AI Orchestration
  │
  ├── Controlled Tools
  ├── Authorization
  ├── Safety Rules
  └── Provider Integration
          │
          ▼
       AI Model
```

AI should not receive unrestricted database access.

AI actions must remain subject to application authorization and domain rules.

Health and medicine AI functionality must remain bounded and non-diagnostic.

## 12. Offline and Synchronization

Offline-first behavior is a future capability.

The architecture should leave room for:

- Local client storage
- Change tracking
- Synchronization
- Conflict handling
- Retryable operations

Offline synchronization should not be introduced before the basic online data model and ownership rules are stable.

## 13. Infrastructure

Initial infrastructure should remain intentionally small.

The current development environment uses:

- PostgreSQL in Docker
- Spring Boot backend
- Flutter frontend

Kubernetes, Kafka, microservices, and other distributed infrastructure are not initial requirements.

They should only be introduced when a concrete scalability, reliability, or operational requirement justifies them.

## 14. Observability

The backend should provide:

- Health endpoints
- Structured application logging
- Useful error information
- Metrics where appropriate

Observability must not leak sensitive user information.

## 15. Testing Strategy

Testing should exist at multiple levels:

### Backend

- Unit tests
- Service/domain tests
- Repository/integration tests
- API/controller tests

### Frontend

- Unit tests
- Widget tests
- Integration tests

### System

Critical user journeys should eventually have end-to-end coverage.

## 16. Architectural Evolution

The architecture should evolve from a strong modular foundation.

The intended progression is:

```
Modular Monolith
       ↓
Measured bottlenecks
       ↓
Explicit architectural decision
       ↓
Selective extraction only when justified
```

The system should not adopt distributed architecture merely because it is technologically possible.

Every major architectural change should be recorded as an Architecture Decision Record (ADR).
