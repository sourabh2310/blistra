# Blistra — Security Principles

## 1. Purpose

Security is a foundational requirement of Blistra.

Blistra may contain highly sensitive personal information, including:

- Health information
- Medicine information
- Financial information
- Personal schedules
- Habits and routines
- Documents
- Goals and personal notes
- AI interactions

Security must therefore be considered at the architecture, backend, frontend, database, infrastructure, and operational levels.

---

## 2. Core Security Principle

The backend is the security boundary.

The client application must never be trusted to enforce authorization.

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

A request is allowed only when all applicable checks succeed.

---

## 3. Authentication

Authentication establishes who the user is.

The backend must validate authentication credentials or tokens before allowing access to protected resources.

Authentication implementation details may evolve, but protected backend endpoints must never rely solely on client-provided identity information.

The backend must determine the authenticated user from the trusted authentication context.

---

## 4. Authorization

Authentication and authorization are separate concerns.

A valid authenticated user does not automatically have access to every resource.

Authorization must determine whether the authenticated user is allowed to perform the requested operation.

Examples include:

- Reading a resource
- Creating a resource
- Updating a resource
- Deleting a resource
- Performing a privileged operation

Authorization must be enforced server-side.

---

## 5. Resource Ownership

User-owned resources must have explicit ownership.

For example:

```
User
  │
  ├── Health Records
  ├── Medicines
  ├── Habits
  ├── Finance Records
  ├── Planner Items
  └── Documents
```

A request for a resource must verify that the resource belongs to the authenticated user or that the user otherwise has explicit permission to access it.

A resource identifier alone must never be treated as proof of authorization.

---

## 6. Preventing Insecure Direct Object Access

Endpoints must not assume that possession of an ID grants access.

Unsafe pattern:

```
GET /api/v1/health-records/123
```

where the backend simply loads record `123`.

The backend must verify that record `123` is accessible to the authenticated user.

The same principle applies to:

- Read
- Update
- Delete
- Search
- Export
- Sharing
- AI-assisted operations

---

## 7. Input Validation

All externally supplied input must be validated.

Validation should occur at API boundaries.

Examples include:

- Required fields
- String lengths
- Numeric ranges
- Valid dates
- Valid enumerations
- Valid identifiers
- Domain-specific constraints

Validation errors should produce consistent API responses.

Validation must not be treated as a replacement for authorization or business rules.

---

## 8. Business Rules

Security-sensitive business rules must be enforced on the backend.

The frontend may provide convenient UI validation, but backend validation remains authoritative.

Examples:

- A user cannot modify another user's record.
- A user cannot access another user's financial information.
- A user cannot manipulate protected ownership fields.
- An AI operation cannot bypass domain authorization.
- A privileged operation cannot be enabled merely by sending a client-side flag.

---

## 9. Secrets

Secrets must never be committed to Git.

Examples include:

- Database passwords
- API keys
- Authentication secrets
- Encryption keys
- OAuth credentials
- Cloud credentials
- AI provider credentials

Local development secrets should be supplied through environment variables or appropriate local configuration.

Production secrets should use a proper secret-management mechanism.

---

## 10. Environment Separation

Development, testing, staging, and production environments should have separate configuration and credentials.

Development credentials must never be reused as production credentials.

Production databases and services must not be accidentally targeted by local development commands.

---

## 11. Database Security

The database is not a public API.

Applications should access PostgreSQL through the backend application layer.

Database credentials must not be exposed to Flutter clients.

The database user should have only the permissions required by the application.

Database integrity should be supported through:

- Foreign keys
- Constraints
- Appropriate indexes
- Transactions
- Controlled migrations

---

## 12. API Security

Public APIs should:

- Use HTTPS outside local development
- Validate authentication
- Enforce authorization
- Validate input
- Return consistent errors
- Avoid exposing internal implementation details
- Avoid returning unnecessary sensitive fields
- Apply appropriate rate limiting when required

API versioning should use:

```
/api/v1
```

---

## 13. Error Handling

Errors returned to clients should be useful without exposing sensitive internal information.

Do not expose:

- Stack traces
- Database credentials
- SQL details
- Internal filesystem paths
- Authentication secrets
- Infrastructure credentials
- Sensitive personal information

Detailed technical information should remain available only through appropriately protected server-side logs.

---

## 14. Logging

Logs are an operational tool, not a place to store personal data.

Logs should avoid unnecessary exposure of:

- Health information
- Medicine information
- Financial information
- Authentication credentials
- Access tokens
- Personal documents
- Private AI conversations

Sensitive values should be redacted where logging is necessary.

---

## 15. Data Minimization

Blistra should collect and retain only information required for a legitimate product capability.

Features should not collect sensitive information merely because it might be useful later.

Data retention requirements should be considered when designing each domain.

---

## 16. Encryption

Sensitive data should be protected in transit and at rest.

Transport encryption should use HTTPS/TLS outside local development.

Database and infrastructure encryption requirements should be defined as deployment environments mature.

Encryption keys must be managed separately from encrypted data.

---

## 17. Frontend Security

The Flutter application must not contain permanent secrets.

Anything embedded in a client application should be considered potentially discoverable by a user.

The frontend must not contain:

- Production database credentials
- Private API keys
- Backend signing secrets
- Master encryption keys

Client-side checks are for user experience, not authorization.

---

## 18. AI Security

AI must operate inside the application's security model.

AI must not receive unrestricted access to:

- The database
- User records
- Administrative operations
- Authentication systems
- Infrastructure

AI actions should use controlled application tools.

Conceptually:

```
User
  ↓
Backend
  ↓
Authorization
  ↓
AI Orchestration
  ↓
Controlled Tool
  ↓
Domain Service
  ↓
Database
```

The AI model should not be able to bypass authorization by generating a different tool request.

---

## 19. Health and Medicine Safety

Health and medicine features require additional safety boundaries.

Blistra must not present itself as a medical diagnosis or prescription system.

AI-assisted health functionality should remain informational and supportive.

The application should avoid presenting uncertain AI-generated information as established medical fact.

Where appropriate, users should be encouraged to consult qualified healthcare professionals.

---

## 20. File and Document Security

Future document functionality must treat uploaded files as untrusted input.

Document handling should eventually consider:

- File type validation
- File size limits
- Malware scanning where appropriate
- Access control
- Secure storage
- Download authorization
- Safe filenames
- Retention and deletion

Documents must never become publicly accessible merely because a storage URL is known.

---

## 21. Auditability

Security-relevant operations should eventually have appropriate audit records.

Potential examples:

- Authentication events
- Security-sensitive changes
- Permission changes
- Data exports
- Document access
- Administrative operations

Audit logging must itself avoid unnecessarily storing sensitive content.

---

## 22. Dependency Security

Dependencies should be kept reasonably current.

Before introducing a dependency, consider:

- Whether it is necessary
- Maintenance status
- Security history
- License
- Transitive dependencies
- Long-term maintenance cost

Security updates should be applied deliberately and tested.

---

## 23. Privacy by Design

Privacy should be considered before implementing a feature rather than after implementation.

For each feature, consider:

1. What personal data is collected?
2. Why is it required?
3. Who can access it?
4. How long is it retained?
5. How is it protected?
6. What happens when the user deletes it?
7. Does AI have access to it?
8. Is that AI access necessary?

---

## 24. Security Development Checklist

Before considering a protected feature complete:

- Authentication is enforced where required
- Authorization is enforced server-side
- Resource ownership is verified
- Input is validated
- Business rules are enforced
- Sensitive fields are not unnecessarily returned
- Secrets are not committed
- Logs do not expose sensitive information
- Database constraints are appropriate
- Error responses do not leak implementation details
- Tests cover unauthorized access
- Tests cover cross-user access attempts

---

## 25. Security Evolution

Security requirements will become more detailed as Blistra gains:

- Authentication flows
- Multiple devices
- Documents
- Notifications
- AI capabilities
- Offline synchronization
- Cloud deployment
- Sharing
- Administrative functionality

Security decisions should be documented as the architecture evolves.

Major security-related architectural decisions should be recorded as Architecture Decision Records.
