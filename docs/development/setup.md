# Blistra — Development Setup

## 1. Purpose

This document describes the local development environment required to build and run Blistra.

The setup is intended to be reproducible on a Windows development machine and should be updated when development prerequisites or workflows change.

---

## 2. Repository

The project repository is structured as:

```
blistra/
├── backend/
├── frontend/
├── infrastructure/
├── docs/
└── scripts/
```

### Backend

The backend is a Java/Spring Boot application.

### Frontend

The frontend is a Flutter application.

### Infrastructure

Infrastructure configuration and local development infrastructure belong here.

### Documentation

Project documentation belongs under `docs/`.

### Scripts

Reusable development and automation scripts belong under `scripts/`.

---

## 3. Required Tooling

The current development environment uses:

ToolPurposeGitSource controlGitHub CLIRepository and GitHub operationsPowerShell 7Primary Windows shellJava 21Backend runtime and compilationMaven WrapperBackend build toolingSpring BootBackend application frameworkPostgreSQL 17Primary relational databaseDocker DesktopLocal infrastructureFlutterCross-platform application developmentDartFlutter programming languageAndroid StudioAndroid development and emulatorAndroid SDKAndroid build and runtimeWSL2 / UbuntuLinux development environment when requiredNode.js / npmSupporting frontend toolingPythonSupporting development toolingBrunoAPI development and testing

Global Maven installation is not required. The backend uses the Maven Wrapper included in the repository.

---

## 4. Java

Blistra backend development uses Java 21.

Verify:

```
java -version
javac -version
```

Expected major version:

```
21
```

`JAVA_HOME` should point to the installed Java 21 JDK.

Verify:

```
$env:JAVA_HOME
```

---

## 5. Backend Build

The backend is built using the Maven Wrapper.

From the repository root:

```
cd C:\Users\patel\blistra\backend
```

Run tests:

```
.\mvnw.cmd clean test
```

The Maven Wrapper should be preferred over requiring a globally installed Maven version.

---

## 6. Running the Backend

From:

```
C:\Users\patel\blistra\backend
```

start the application with:

```
.\mvnw.cmd spring-boot:run
```

The backend runs on:

```
http://localhost:8080
```

The current backend configuration uses the user's local development timezone for the application JVM while keeping database timestamp handling in UTC.

---

## 7. PostgreSQL

PostgreSQL is provided locally through Docker.

Current development database:

```
Database: lifesight
Username: lifesight
Password: devpassword
Host: localhost
Port: 5432
```

The database is currently running in a Docker container named:

```
lifesight-postgres
```

Check the container:

```
docker ps
```

The container should show PostgreSQL running on port `5432`.

---

## 8. PostgreSQL Timezone

The PostgreSQL server uses UTC.

Verify:

```
docker exec lifesight-postgres psql -U lifesight -d lifesight -c "SHOW timezone;"
```

Expected result:

```
Etc/UTC
```

Database persistence should remain timezone-consistent and should not depend on changing the PostgreSQL server timezone to match an individual user's location.

---

## 9. Backend Database Configuration

The backend reads database configuration through environment variables.

Current development defaults are:

```
DB_URL=jdbc:postgresql://localhost:5432/lifesight
DB_USERNAME=lifesight
DB_PASSWORD=devpassword
```

For local development, the password may be supplied through the PowerShell session:

```
$env:DB_PASSWORD="devpassword"
```

Production credentials must never be committed to Git.

---

## 10. Flutter

Verify Flutter:

```
flutter --version
```

Run Flutter diagnostics:

```
flutter doctor
```

The Flutter SDK is installed at:

```
C:\src\flutter
```

Flutter should be available from the system `PATH`.

---

## 11. Frontend

The Flutter application is located at:

```
C:\Users\patel\blistra\frontend
```

Enter the frontend directory:

```
cd C:\Users\patel\blistra\frontend
```

Install dependencies:

```
flutter pub get
```

Analyze the project:

```
flutter analyze
```

Run tests:

```
flutter test
```

---

## 12. Android Development

Android Studio provides the Android SDK and emulator tooling.

The Android SDK is installed under the user's local Android SDK directory.

Verify connected devices:

```
flutter devices
```

Start the configured Android emulator when required.

The current development emulator is:

```
Pixel_6
```

with Android API 36.

Run the Flutter application on the emulator:

```
flutter run -d emulator-5554
```

Build a debug APK:

```
flutter build apk --debug
```

---

## 13. API Testing

Bruno is used for manual API testing.

The local backend base URL is:

```
http://localhost:8080
```

The health endpoint is:

```
GET /actuator/health
```

Full local endpoint:

```
http://localhost:8080/actuator/health
```

A healthy backend should return HTTP `200` with a status indicating that the application is operational.

---

## 14. Git

Git is the source-control system.

The primary branch is:

```
main
```

Check repository state:

```
git status
```

View recent commits:

```
git log --oneline --decorate -10
```

Before committing changes:

```
git status
```

After committing:

```
git status
```

The preferred state after a completed commit is:

```
nothing to commit, working tree clean
```

---

## 15. GitHub

The project is hosted in a private GitHub repository.

The local repository uses:

```
origin
```

as the remote.

Verify:

```
git remote -v
```

Push the current branch:

```
git push origin main
```

Do not commit:

- Passwords
- API keys
- Access tokens
- Private certificates
- Production credentials
- Local environment files containing secrets

---

## 16. Environment Variables and Secrets

Local secrets should be supplied through environment variables or local configuration that is excluded from Git.

The repository `.gitignore` excludes environment files such as:

```
.env
.env.*
```

with an explicit exception for:

```
.env.example
```

An example configuration may document required variables without containing real credentials.

---

## 17. Docker

Docker Desktop provides local infrastructure support.

Verify:

```
docker version
```

Verify Compose:

```
docker compose version
```

List running containers:

```
docker ps
```

PostgreSQL should be the primary local container during current backend development.

---

## 18. WSL2

WSL2 is available for Linux-based development workflows.

Verify:

```
wsl --status
```

WSL should not replace the Windows development workflow unless a specific task benefits from Linux tooling.

---

## 19. Development Workflow

A normal development session should generally follow this sequence:

### Start infrastructure

Ensure PostgreSQL is running:

```
docker ps
```

Start it if required:

```
docker start lifesight-postgres
```

### Start backend

```
cd C:\Users\patel\blistra\backend
.\mvnw.cmd spring-boot:run
```

### Start frontend

In another PowerShell window:

```
cd C:\Users\patel\blistra\frontend
flutter run
```

### Test changes

Backend:

```
.\mvnw.cmd clean test
```

Frontend:

```
flutter analyze
flutter test
```

### Check Git

From the repository root:

```
cd C:\Users\patel\blistra
git status
```

---

## 20. Important Development Rules

### Do not bypass backend authorization

The frontend is not a security boundary.

### Do not expose persistence entities directly

Use API DTOs.

### Do not store secrets in Git

Use environment variables or appropriate secret-management mechanisms.

### Do not change PostgreSQL away from UTC for convenience

User timezone handling belongs at the application/user level.

### Do not introduce unnecessary distributed infrastructure

The initial architecture is a modular monolith.

### Do not make health or medicine features diagnostic or prescriptive

These areas require additional safety boundaries.

### Do not introduce large dependencies without justification

Prefer a small, understandable dependency set.

---

## 21. Setup Verification Checklist

A development environment is considered ready when the following are working:

- Git
- GitHub authentication
- Java 21
- Maven Wrapper
- Docker Desktop
- PostgreSQL
- Spring Boot backend
- Backend database connection
- Backend health endpoint
- Flutter
- Dart
- Android SDK
- Android emulator
- Flutter analysis
- Flutter tests
- Bruno API testing

---

## 22. Keeping This Document Current

Update this document when:

- A required development tool changes
- A required version changes
- The repository structure changes significantly
- The database setup changes
- The backend startup process changes
- The frontend startup process changes
- A new required environment variable is introduced
- A development workflow becomes standardized

The goal is to document the actual supported development workflow, not every tool installed on an individual machine.
