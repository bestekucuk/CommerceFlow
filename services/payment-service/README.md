# payment-service

Payments bounded context of CommerceFlow. Payment authorization, capture, void and refund through a provider adapter (provider not chosen, CF-016).

## Status

**Buildable scaffold.** Spring Boot application with health/readiness probes, Flyway
baseline (outbox, inbox), architecture test and a Testcontainers
health test. No business logic, API endpoints or Kafka integration yet.

## Stack

Kotlin 2.0, Spring Boot 3.3, Gradle Kotlin DSL (wrapper in this folder), Flyway,
PostgreSQL (`payment_db`), JUnit 5, ArchUnit, Testcontainers. Bytecode target: Java 17.

## Local development

From this folder (Windows: `gradlew.bat`):

| Task | Command |
|---|---|
| Build + unit tests | `./gradlew build` |
| Integration tests (Docker) | `./gradlew integrationTest` |
| Run | `DB_URL=jdbc:postgresql://localhost:5432/payment_db DB_USER=... DB_PASSWORD=... ./gradlew bootRun` |
| Image | from the repo root: `powershell -File scripts/build-service.ps1 payment-service -Image` |

| Endpoint | Purpose |
|---|---|
| `GET /actuator/health/liveness` | liveness probe |
| `GET /actuator/health/readiness` | readiness probe (includes the database) |
| `GET /actuator/prometheus` | metrics |

Port: `8084` (`PORT`). Configuration: `src/main/resources/application.yml` (environment
variables `DB_URL`, `DB_USER`, `DB_PASSWORD`, `PORT`).

## Integration

- Publishes: PaymentAuthorized, PaymentFailed, PaymentVoided, PaymentRefunded
- Consumes: Commands AuthorizePayment, VoidPayment; OrderCancelled
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
