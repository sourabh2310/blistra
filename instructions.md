You are working on the Blistra repository.

Blistra is a production-oriented, privacy-first, mobile-first personal life-management platform. The repository contains the initial project foundation and documentation.

Your task in this phase is to implement and verify the **backend foundation only**.

Do NOT implement Health, Medicines, Diet, Habits, Finance, Planner, Dashboard, AI, Payments, UPI, Documents, Notifications, or offline synchronization yet.

The goal is to create a clean, runnable, testable backend foundation that later feature modules can build on.

---

# 1. FIRST: INSPECT THE REPOSITORY

Before changing anything:

1. Inspect the complete repository structure.
2. Read the existing README and relevant documentation.
3. Inspect the existing backend structure, if present.
4. Inspect the existing frontend structure, but do not modify frontend code unless absolutely necessary for an existing build/configuration issue.
5. Inspect existing Git configuration and project conventions.
6. Inspect existing Java/Spring Boot configuration.
7. Inspect existing Docker configuration.
8. Inspect existing CI configuration.
9. Inspect existing tests.
10. Identify what has already been implemented versus what is only documented.

Do NOT blindly recreate files that already exist.

Preserve working code.

Do not replace the existing architecture simply because you would personally structure it differently.

If an existing implementation conflicts with the Blistra architecture described below, make the smallest reasonable change necessary and explain the conflict.

---

# 2. SOURCE OF ARCHITECTURAL TRUTH

Use the existing repository documentation as the primary source of truth.

The intended backend architecture is:

* Java 21
* Spring Boot
* Maven Wrapper
* PostgreSQL
* REST APIs
* `/api/v1/...` API namespace
* DTO-based API contracts
* Bean Validation
* Authentication
* Authorization
* Resource ownership enforcement
* Structured error responses
* OpenAPI/Swagger
* Modular monolith
* Production-quality foundations
* Testable architecture

Do NOT introduce microservices.

Do NOT introduce Kafka.

Do NOT introduce Kubernetes.

Do NOT introduce Redis unless the existing project already requires it for a concrete reason.

Do NOT introduce an event bus merely for future-proofing.

Do NOT introduce unnecessary infrastructure.

Keep the system simple.

---

# 3. TARGET BACKEND STRUCTURE

Use a modular-monolith structure.

A reasonable structure is:

backend/
src/
main/
java/ <base-package>/
...
resources/
application.yml
application-dev.yml
db/
migration/
test/
java/ <base-package>/
...

Use the repository's existing base package if one already exists.

Do NOT rename packages unnecessarily.

Within the backend, maintain clear boundaries.

At minimum, establish appropriate foundation boundaries for:

* auth
* users
* common/core infrastructure

Future modules will later include:

* dashboard
* planner
* health
* medicines
* diet
* habits
* finance
* documents
* notifications
* ai

Do not implement those future modules now.

---

# 4. APPLICATION CONFIGURATION

Ensure the Spring Boot backend can start cleanly.

Use:

* Java 21
* Spring Boot version already established by the repository, if present
* Maven Wrapper
* YAML/properties configuration appropriate to the existing project

Configuration must not contain secrets.

Do NOT hard-code:

* database passwords
* JWT secrets
* API keys
* production credentials
* encryption keys

Use environment variables for secrets and environment-specific configuration.

Create a sensible development profile if one does not already exist.

For example, development configuration may use environment variables such as:

DB_HOST
DB_PORT
DB_NAME
DB_USERNAME
DB_PASSWORD

Use the project's existing naming conventions if they already exist.

---

# 5. POSTGRESQL DEVELOPMENT ENVIRONMENT

If PostgreSQL/Docker configuration does not already exist, add a minimal Docker Compose configuration for local development.

Requirements:

* PostgreSQL only
* Persistent development volume
* Environment-based credentials
* No unnecessary infrastructure
* No application container required unless the repository already uses that approach

The developer should be able to start PostgreSQL locally with a simple command.

Do not commit real credentials.

Provide safe development defaults only where appropriate.

---

# 6. DATABASE MIGRATIONS

Use a proper database migration mechanism.

Prefer the technology already present in the repository.

If no migration mechanism exists, use Flyway unless there is a strong repository-specific reason not to.

Do not rely on Hibernate automatically creating production schema.

The database schema should be reproducible from migrations.

Create the initial migration for the user/auth foundation.

---

# 7. USER DOMAIN

Implement the initial User domain.

The user entity should have an appropriate minimal schema.

At minimum, consider:

* id
* email
* password hash
* status
* createdAt
* updatedAt

Use an appropriate UUID strategy for user identifiers unless the existing architecture has already selected another secure identifier strategy.

Do NOT store plaintext passwords.

Do NOT store unnecessary personal information yet.

Keep the User model minimal.

The User domain should be extensible later without coupling it to Health, Finance, etc.

---

# 8. USER DATABASE REQUIREMENTS

Create proper database constraints.

At minimum:

* primary key
* unique email
* not-null requirements where appropriate
* timestamps
* appropriate status representation

Normalize email consistently for authentication.

Be careful about case sensitivity.

Do not rely only on application-level uniqueness checks.

The database must enforce uniqueness.

---

# 9. PASSWORD SECURITY

Implement secure password hashing.

Use Spring Security's recommended password hashing mechanism appropriate for the selected Spring Boot/Spring Security version.

Do NOT implement custom cryptographic password hashing.

Do NOT use:

* MD5
* SHA-1
* plain SHA-256
* plaintext passwords
* reversible encryption for passwords

Passwords must only be stored as secure password hashes.

---

# 10. AUTHENTICATION

Implement a minimal secure authentication flow.

At this phase implement:

## Registration

Endpoint concept:

POST /api/v1/auth/register

Input should be a request DTO.

Do not expose database entities directly.

Validate:

* email
* password

Return a safe response DTO.

Do not return:

* password
* password hash
* internal security fields

## Login

Endpoint concept:

POST /api/v1/auth/login

Validate credentials securely.

Return the authentication mechanism selected by the existing project architecture.

If no mechanism exists yet, use a simple stateless JWT-based authentication design appropriate for this stage.

Do not implement refresh tokens unless they are required by the existing architecture.

If JWT is used:

* keep signing configuration externalized
* never hard-code the signing secret
* validate signature
* validate expiration
* include only necessary claims
* do not place sensitive user data in claims

Keep authentication simple but structurally extensible.

---

# 11. SPRING SECURITY

Configure Spring Security properly.

Public endpoints should include only endpoints that genuinely need to be public, such as:

* registration
* login
* health check

Everything else should require authentication.

Do NOT disable security globally.

Do NOT use permissive configuration simply to make development easier.

Do NOT rely on frontend authentication.

The backend must enforce authentication.

---

# 12. AUTHORIZATION AND USER OWNERSHIP

This is extremely important.

Blistra is a multi-user application.

Never assume there will be only one user.

Every user-owned resource must eventually be associated with its owner.

For the initial User/Auth implementation, ensure that authenticated identity can be reliably obtained from the backend security context.

Do not trust a user ID supplied by the client to identify the current authenticated user.

For example, avoid designs where a request says:

"userId": "some-id"

and the backend blindly trusts it.

The server should derive the authenticated user identity from the authentication context.

Future domain modules must be able to use this ownership mechanism.

---

# 13. DTO ARCHITECTURE

Do not expose JPA entities directly through REST controllers.

Create request/response DTOs.

For example, conceptually:

RegisterRequest
LoginRequest
AuthResponse
UserResponse

Use whatever naming conventions already exist in the repository.

DTOs should define the API contract.

Entities should remain internal persistence/domain representations.

---

# 14. VALIDATION

Use Jakarta Bean Validation / Spring validation.

Validate incoming request DTOs.

At minimum:

Email:

* required
* valid email format
* normalized appropriately

Password:

* required
* reasonable minimum length
* do not impose arbitrary complexity requirements without justification

Do not leak detailed information that could assist account enumeration unnecessarily.

---

# 15. ERROR HANDLING

Implement consistent API error responses.

Create a common structured error representation.

A reasonable response shape is conceptually:

{
"timestamp": "...",
"status": 400,
"code": "VALIDATION_ERROR",
"message": "Request validation failed",
"path": "/api/v1/auth/register",
"errors": [...]
}

The exact structure can follow existing repository conventions.

Handle at least:

* validation failures
* authentication failures
* authorization failures
* resource-not-found cases where applicable
* duplicate email
* malformed requests
* unexpected server errors

Do not expose:

* stack traces
* SQL queries
* internal exception details
* passwords
* secrets
* sensitive data

to API clients.

---

# 16. API VERSIONING

Use:

/api/v1/...

Do not create unversioned business APIs such as:

/auth/login

when the intended architecture specifies:

/api/v1/auth/login

Keep versioning consistent.

---

# 17. OPENAPI

Add OpenAPI/Swagger support if it is not already present.

Document:

* authentication endpoints
* request DTOs
* response DTOs
* validation behavior
* error responses

Do not expose sensitive implementation details.

The OpenAPI contract should reflect the actual API.

Do not create documentation for endpoints that do not exist.

---

# 18. HEALTH CHECK

Provide a basic application health endpoint.

Use the appropriate Spring Boot Actuator mechanism if Actuator is already used or appropriate.

The health endpoint should be useful for local development and future deployment.

Do not expose unnecessary sensitive system information.

---

# 19. LOGGING AND PRIVACY

Use structured, useful logging.

Do NOT log:

* passwords
* password hashes
* JWTs
* authentication headers
* database credentials
* health information
* financial information
* personal documents
* sensitive user data

Authentication failures may be logged in a privacy-conscious way.

Avoid logging entire request bodies for authentication endpoints.

---

# 20. TESTING

This implementation is NOT complete until tests exist.

Add tests for the important behavior.

At minimum:

### Registration

Test:

* successful registration
* invalid email
* invalid password
* duplicate email
* password is not stored as plaintext
* password hash is not returned in API response

### Login

Test:

* successful login
* incorrect password
* unknown user
* malformed request

### Security

Test:

* protected endpoint rejects unauthenticated requests
* authenticated request is accepted where appropriate
* authentication identity is correctly resolved

### Ownership foundation

Add at least one test demonstrating that backend authorization is based on authenticated identity rather than trusting arbitrary client-provided identity.

### Database

Add repository/integration coverage appropriate to the project's existing test setup.

Prefer Testcontainers for PostgreSQL integration tests if the project already uses Testcontainers or if introducing it is justified.

Do NOT introduce a large testing infrastructure unnecessarily.

---

# 21. TEST QUALITY

Do not write tests merely to increase coverage numbers.

Tests should protect important behavior.

Prioritize:

* authentication
* authorization
* ownership
* password security
* database constraints
* API contracts
* validation

Use clear test names.

Keep tests maintainable.

---

# 22. TRANSACTION BOUNDARIES

Use appropriate transactional boundaries in service/domain operations.

Do not put `@Transactional` randomly everywhere.

Registration and other database mutations should have clear transaction boundaries.

Keep controllers thin.

Business logic should live in services/domain layers rather than controllers.

---

# 23. ARCHITECTURAL RULES

Follow these rules:

Controller
↓
Service / Application layer
↓
Repository
↓
Database

Do not put business logic in controllers.

Do not put HTTP concerns in repositories.

Do not expose entities as public API contracts.

Do not let unrelated modules directly manipulate each other's persistence models.

Prefer explicit module boundaries.

---

# 24. SECURITY PRINCIPLE

For every future request, the intended security flow is:

Authentication
↓
Authorization
↓
Resource ownership
↓
Business rule validation
↓
Operation

Build the foundation so future modules can follow this consistently.

Never rely on:

"The Flutter app won't send that."

Assume the client is malicious.

---

# 25. TIME AND AUDIT FIELDS

Use appropriate timestamp handling.

The application must be timezone-aware where appropriate.

For persisted audit timestamps, use a consistent strategy compatible with PostgreSQL and the application's future internationalization requirements.

Do not scatter `LocalDateTime.now()` throughout business logic.

Prefer an injectable/centralized time abstraction where appropriate if the existing architecture supports it.

Do not over-engineer this.

---

# 26. DEPENDENCY DISCIPLINE

Before adding dependencies:

1. Check whether the functionality already exists.
2. Check the current Spring Boot version.
3. Use dependencies compatible with Java 21.
4. Add only dependencies justified by this phase.

Do not add libraries simply because they are popular.

Avoid unnecessary frameworks.

---

# 27. DOCUMENTATION

Update documentation only where implementation has changed reality.

Document:

* how to start PostgreSQL
* how to configure environment variables
* how to start the backend
* how to run tests
* available authentication endpoints
* development setup
* relevant architecture decisions

Do not create large documentation files for things that are obvious.

If an architectural decision is significant, add an ADR under the existing documentation structure.

---

# 28. GIT SAFETY

Do NOT:

* rewrite Git history
* force push
* delete unrelated files
* reset existing work
* overwrite working implementation unnecessarily
* commit secrets
* commit local credentials

Preserve existing repository history.

Make changes incrementally.

---

# 29. COMMANDS AND VERIFICATION

After implementation:

1. Start PostgreSQL.
2. Run database migrations.
3. Start the Spring Boot backend.
4. Run all backend tests.
5. Run formatting/static checks if configured.
6. Verify authentication endpoints.
7. Verify protected endpoint behavior.
8. Verify database constraints.
9. Inspect the final Git diff.
10. Ensure no secrets or generated files were accidentally added.

Use the Maven Wrapper.

On Windows, use:

`mvnw.cmd`

Do not assume globally installed Maven.

If using WSL, adapt commands appropriately.

---

# 30. IMPORTANT: DO NOT STOP AT COMPILATION

A successful compilation is not sufficient.

The implementation must be behaviorally verified.

If a test fails:

* investigate the root cause
* fix the implementation
* rerun the relevant test
* rerun the complete test suite

Do not simply disable the failing test.

Do not weaken security to make tests pass.

---

# 31. DO NOT IMPLEMENT FUTURE FEATURES

Explicitly do NOT implement:

* Health
* Medicines
* Diet
* Habits
* Finance
* Planner
* Dashboard
* Documents
* Notifications
* AI
* Payments
* UPI
* Family accounts
* SaaS billing
* Microservices
* Kubernetes
* Kafka
* Advanced offline synchronization
* Advanced analytics

Only create minimal extension points where they naturally arise from the foundation.

---

# 32. FINAL REVIEW BEFORE FINISHING

Before declaring the task complete, review the implementation as a senior backend engineer.

Ask:

### Architecture

* Is the backend still a modular monolith?
* Are controllers thin?
* Is business logic outside controllers?
* Are DTOs separated from entities?

### Security

* Are passwords securely hashed?
* Are secrets externalized?
* Are protected endpoints actually protected?
* Is authenticated identity derived server-side?
* Is user ownership enforced?
* Are sensitive values excluded from logs/errors?

### Database

* Is email uniqueness enforced by the database?
* Are migrations reproducible?
* Are timestamps handled correctly?
* Are unnecessary fields avoided?

### API

* Are APIs under `/api/v1`?
* Are validation errors consistent?
* Are authentication errors handled safely?
* Are entities hidden behind DTOs?

### Testing

* Do authentication tests pass?
* Do authorization tests pass?
* Do database tests pass?
* Does the entire test suite pass?

### Maintainability

* Is the implementation understandable?
* Did we avoid unnecessary abstractions?
* Did we avoid premature infrastructure?
* Is the foundation easy for future feature modules to extend?

---

# 33. OUTPUT REQUIRED FROM YOU

When the implementation is complete, do NOT merely say "done".

Provide a concise implementation report containing:

1. What already existed before your changes.
2. What files/modules you added.
3. What files/modules you changed.
4. Database schema/migrations added.
5. API endpoints implemented.
6. Authentication approach used.
7. Authorization/ownership approach used.
8. Dependencies added.
9. Tests added.
10. Commands used to verify the implementation.
11. Test result.
12. Any known limitations.
13. Any architectural decisions that require my review.

Do not claim success if tests could not be run.

If something cannot be implemented because the repository differs from the expected structure, stop and explain the discrepancy rather than making a large speculative rewrite.

The priority is:

Correctness
Security
Simplicity
Maintainability
Testability

Do not optimize for the number of files or amount of code produced.

Implement the smallest complete, production-quality backend foundation that establishes the base for the rest of Blistra.
