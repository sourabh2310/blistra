# Blistra Backend Foundation — Development Setup

This document describes how to set up and run the Blistra backend foundation for local development.

## Prerequisites

- Java 21
- Docker and Docker Compose
- Maven Wrapper (included in repository)
- Environment variables configuration

## 1. PostgreSQL Setup

The backend requires PostgreSQL for development. Use Docker Compose to start PostgreSQL:

```bash
cd C:\Users\patel\blistra
docker-compose up -d
```

This command starts PostgreSQL with:
- Database: `blistra`
- Username: `blistra`
- Password: `blistra`
- Port: `5432`

Verify the database is running:

```bash
docker-compose ps
```

Stop the database:

```bash
docker-compose down
```

## 2. Environment Variables

Create a `.env` file in the project root (or set environment variables in your shell):

```bash
# PostgreSQL
DB_URL=jdbc:postgresql://localhost:5432/blistra
DB_USERNAME=blistra
DB_PASSWORD=blistra
DB_NAME=blistra

# JWT (use a strong 256-bit secret in production)
JWT_SECRET=your-256-bit-secret-key-minimum-32-bytes-change-in-production
JWT_EXPIRATION=86400000

# Spring Profile
SPRING_PROFILES_ACTIVE=dev
```

In PowerShell, set variables:

```powershell
$env:DB_USERNAME="blistra"
$env:DB_PASSWORD="blistra"
$env:JWT_SECRET="your-256-bit-secret-key-minimum-32-bytes"
```

## 3. Build the Backend

From the backend directory:

```bash
cd C:\Users\patel\blistra\backend
.\mvnw.cmd clean package
```

This will:
- Compile the Java code
- Run all tests
- Create a packaged JAR file

## 4. Run Database Migrations

Migrations are automatically run when the Spring Boot application starts (via Flyway).

Verify migrations by checking the application logs:

```bash
cd C:\Users\patel\blistra\backend
.\mvnw.cmd spring-boot:run
```

Migrations are located in:

```
backend/src/main/resources/db/migration/
```

## 5. Start the Backend

From the backend directory:

```bash
cd C:\Users\patel\blistra\backend
.\mvnw.cmd spring-boot:run
```

The backend will:
1. Start on `http://localhost:8080`
2. Run Flyway migrations
3. Initialize the database schema

## 6. Verify the Backend is Running

Health check endpoint:

```bash
curl http://localhost:8080/health
```

Expected response:

```json
{"status": "UP"}
```

## 7. API Documentation

Swagger UI is available at:

```
http://localhost:8080/swagger-ui.html
```

OpenAPI JSON is available at:

```
http://localhost:8080/v3/api-docs
```

## 8. Run Tests

Run all backend tests:

```bash
cd C:\Users\patel\blistra\backend
.\mvnw.cmd test
```

Run specific test class:

```bash
.\mvnw.cmd test -Dtest=AuthControllerIntegrationTest
```

Tests use Testcontainers to spin up a temporary PostgreSQL database for integration testing.

## 9. Authentication Endpoints

### Register

```bash
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

Response:

```json
{
  "id": "uuid",
  "email": "user@example.com",
  "status": "ACTIVE",
  "createdAt": "2024-01-01T00:00:00",
  "updatedAt": "2024-01-01T00:00:00"
}
```

### Login

```bash
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "password123"
  }'
```

Response:

```json
{
  "token": "eyJ...",
  "tokenType": "Bearer",
  "expiresIn": 86400,
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "status": "ACTIVE",
    "createdAt": "2024-01-01T00:00:00",
    "updatedAt": "2024-01-01T00:00:00"
  }
}
```

## 10. Protected Endpoints

Use the JWT token for authenticated requests:

```bash
curl -H "Authorization: Bearer <token>" http://localhost:8080/api/v1/protected-endpoint
```

## 11. Database Access

Connect directly to PostgreSQL:

```bash
docker exec -it blistra-postgres psql -U blistra -d blistra
```

List tables:

```sql
\dt
```

View users table:

```sql
SELECT id, email, status, created_at, updated_at FROM users;
```

## 12. Troubleshooting

### PostgreSQL connection error

Ensure PostgreSQL is running:

```bash
docker-compose ps
```

If not running, start it:

```bash
docker-compose up -d
```

### Port already in use

If port 8080 is in use, change the port in application-dev.yml:

```yaml
server:
  port: 8081
```

### JWT secret too short

JWT_SECRET must be at least 32 bytes (256 bits) for HS256:

```powershell
$env:JWT_SECRET = "a" * 32  # 32 character secret minimum
```

### Migration failures

Clear the database and restart:

```bash
docker-compose down -v
docker-compose up -d
```

## 13. Development Workflow

1. Start PostgreSQL: `docker-compose up -d`
2. Run backend: `.\mvnw.cmd spring-boot:run`
3. Access API: `http://localhost:8080`
4. View docs: `http://localhost:8080/swagger-ui.html`
5. Run tests: `.\mvnw.cmd test`
6. Stop: Ctrl+C, then `docker-compose down`
