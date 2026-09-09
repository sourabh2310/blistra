# Blistra — Product Vision

## 1. Product

**Blistra — Everything you need. One app.**

Blistra is a personal life-management platform designed to bring important areas of everyday life into one connected system.

The product combines:

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

The goal is not to create a collection of disconnected utilities. Blistra should provide one coherent personal system where information, routines, plans, reminders, and progress can work together.

## 2. Product Principles

### One system

Blistra should feel like one product rather than a collection of unrelated modules.

### Clear ownership

Each domain owns its own data and business rules. The Planner orchestrates information but does not become the owner of every domain.

### Safety first

Health and medicine functionality must remain informational and supportive.

Blistra must not:

- Diagnose medical conditions
- Prescribe medication
- Replace professional medical advice

AI functionality must operate within explicit safety and authorization boundaries.

### Privacy by design

Personal data is sensitive. The system must enforce authentication, authorization, resource ownership, secure handling of secrets, and privacy-aware logging.

### Mobile first

Android is the highest-priority client platform, followed by iOS and Web.

### Build the foundation before the scale

Blistra starts as a modular monolith with clear internal boundaries.

Microservices, Kafka, Kubernetes, and other distributed infrastructure are not part of the initial architecture unless a concrete requirement justifies them later.

## 3. V1 Scope

The initial product scope focuses on:

1. Dashboard
2. Planner
3. Health
4. Medicines
5. Diet
6. Habits
7. Finance

The Dashboard provides a useful overview.

The Planner provides timeline and orchestration capabilities.

Domain modules remain responsible for their own data and domain rules.

## 4. AI Direction

AI is an assistant layer, not the owner of business logic.

AI should:

- Explain
- Summarize
- Suggest
- Organize
- Assist with planning
- Provide bounded recommendations

AI should not receive unrestricted access to the database or bypass application authorization.

AI interactions should eventually operate through controlled application tools and explicit permissions.

## 5. Long-Term Direction

Blistra should evolve into a reliable personal operating system while preserving:

- Clear domain boundaries
- Strong security
- Useful user experiences
- Maintainable architecture
- Testability
- Observability
- Data integrity

Future capabilities may include richer AI assistance, offline-first synchronization, documents, notifications, goals, analytics, and additional life-management domains.

These capabilities should be introduced incrementally rather than by over-engineering the initial system.
