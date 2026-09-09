# Blistra

## Everything you need. One app.

Blistra is a personal life-management platform designed to bring important areas of everyday life into one connected system.

It brings together:

- Health
- Medicines
- Diet
- Habits
- Planner
- Finance
- Documents
- Notifications
- Goals
- AI-assisted workflows

The goal is to provide one coherent personal system rather than a collection of disconnected utilities.

---

## Project Status

**Current stage: Foundation / Architecture**

The initial development foundation is established:

- Repository created
- Backend initialized
- Flutter frontend initialized
- PostgreSQL development database running
- Spring Boot connected to PostgreSQL
- Android emulator verified
- Backend health endpoint verified
- Flutter analysis passing
- Flutter tests passing
- Core architecture and security documentation established

The product is **not yet feature complete**.

---

## V1 Scope

The initial V1 focuses on:

1. Dashboard
2. Planner
3. Health
4. Medicines
5. Diet
6. Habits
7. Finance

Additional capabilities such as Documents, Notifications, Goals, and richer AI functionality can be introduced incrementally.

---

## Architecture

Blistra starts as a **modular monolith**.

```
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
                    │    Modular Monolith     │
                    │                         │
                    │ Auth / Users             │
                    │ Planner                  │
                    │ Health                   │
                    │ Medicines                │
                    │ Diet                     │
                    │ Habits                  │
                    │ Finance                 │
                    │ Dashboard               │
                    │ Future: AI / Documents  │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │       PostgreSQL        │
                    │      Primary Store      │
                    └─────────────────────────┘
```

### Core architectural principles

- Flutter for Android, iOS, and Web
- Java 21 + Spring Boot for the backend
- PostgreSQL as the primary relational database
- Modular monolith instead of initial microservices
- Versioned REST APIs under `/api/v1`
- DTO-based API contracts
- Server-side authorization and resource ownership
- UTC for database timestamp handling
- User-specific timezone handling at the application level
- AI behind controlled application tools
- Security and privacy by design
- Avoid premature distributed infrastructure

See the detailed architecture documentation:

`docs/architecture/overview.md`

---

## Repository Structure

```
blistra/
├── backend/
│   └── Spring Boot backend
│
├── frontend/
│   └── Flutter application
│
├── infrastructure/
│   └── Infrastructure and deployment configuration
│
├── docs/
│   ├── product/
│   │   └── Product vision and scope
│   │
│   ├── architecture/
│   │   └── System architecture
│   │
│   ├── development/
│   │   └── Development setup and workflow
│   │
│   ├── security/
│   │   └── Security principles
│   │
│   └── decisions/
│       └── Architecture Decision Records
│
└── scripts/
    └── Development and automation scripts
```

---

## Technology Stack

### Frontend

- Flutter
- Dart
- Android
- iOS
- Web

### Backend

- Java 21
- Spring Boot
- Spring Web
- Spring Data JPA
- Bean Validation
- Actuator
- Maven Wrapper

### Database

- PostgreSQL

### Development Infrastructure

- Docker Desktop
- PostgreSQL running in Docker

### Development Tools

- Git
- GitHub
- Bruno
- Android Studio
- Android SDK
- WSL2

---

## Local Development

### Prerequisites

Install the development tools described in:

`docs/development/setup.md`

### Start PostgreSQL

Check running containers:

```
docker ps
```

Start the local database if required:

```
docker start lifesight-postgres
```

### Start Backend

```
cd backend
.\mvnw.cmd spring-boot:run
```

Backend:

```
http://localhost:8080
```

Health check:

```
http://localhost:8080/actuator/health
```

### Start Frontend

Open another PowerShell window:

```
cd frontend
flutter pub get
flutter run
```

For the Android emulator:

```
flutter run -d emulator-5554
```

---

## Testing

### Backend

From `backend/`:

```
.\mvnw.cmd clean test
```

### Frontend

From `frontend/`:

```
flutter analyze
flutter test
```

---

## API

The backend exposes versioned REST APIs.

Base path:

```
/api/v1
```

API contracts should use:

- DTOs
- Validation
- Consistent errors
- Pagination where appropriate
- Filtering and sorting where appropriate
- Resource ownership checks

API documentation will evolve alongside the backend.

---

## Security

Security is a core architectural concern.

The backend follows:

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

The frontend is never considered a trusted authorization boundary.

Secrets must not be committed to Git.

Sensitive personal information should not be unnecessarily exposed through APIs or logs.

Health and medicine functionality must remain informational and must not become a diagnostic or prescription system.

See:

`docs/security/principles.md`

---

## AI

AI is intended to be an assistant layer rather than an unrestricted system interface.

Future AI capabilities may include:

- Explanation
- Summarization
- Planning assistance
- Organization
- Bounded recommendations

AI should operate through controlled application tools and remain subject to authorization and domain rules.

AI must not receive unrestricted database access.

---

## Documentation

### Product

`docs/product/vision.md`

Defines the product direction, V1 scope, principles, and long-term direction.

### Architecture

`docs/architecture/overview.md`

Defines the system architecture, module boundaries, API architecture, data strategy, security model, AI direction, and architectural evolution.

### Development

`docs/development/setup.md`

Documents the local development environment and standard development workflow.

### Security

`docs/security/principles.md`

Defines the security and privacy principles that apply across Blistra.

### Architecture Decisions

`docs/decisions/README.md`

Contains the Architecture Decision Record index and rules for documenting major architectural decisions.

---

## Development Philosophy

Blistra should be built incrementally.

The preferred progression is:

```
Strong Foundation
       ↓
Small Working Feature
       ↓
Tests
       ↓
Validation
       ↓
Measure
       ↓
Improve
```

Avoid:

- Premature microservices
- Unnecessary infrastructure
- Unrestricted AI access
- Large speculative abstractions
- Domain ownership violations
- Client-side authorization
- Secrets in source control

Architectural complexity should be introduced only when the product has a concrete requirement for it.

---

## Contributing

Development conventions and workflows are documented under:

`docs/development/`

Major architectural decisions should be recorded under:

`docs/decisions/`

Code should preserve clear domain boundaries and maintain the security principles defined by the project.

---

## License

License information will be added when the project's distribution model is finalized.
