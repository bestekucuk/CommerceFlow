# customer-service

Customer bounded context of CommerceFlow. Customer profiles, addresses and contact preferences.

## Status

**Buildable scaffold.** Spring Boot application with health/readiness probes, Flyway
baseline (outbox), architecture test and a Testcontainers
health test. No business logic, API endpoints or Kafka integration yet.

## Stack

Kotlin 2.0, Spring Boot 3.3, Gradle Kotlin DSL (wrapper in this folder), Flyway,
PostgreSQL (`customer_db`), JUnit 5, ArchUnit, Testcontainers. Bytecode target: Java 17.

## Local development

From this folder (Windows: `gradlew.bat`):

| Task | Command |
|---|---|
| Build + unit tests | `./gradlew build` |
| Integration tests (Docker) | `./gradlew integrationTest` |
| Run | `DB_URL=jdbc:postgresql://localhost:15432/customer_db DB_USER=... DB_PASSWORD=... ./gradlew bootRun` |
| Image | from the repo root: `powershell -File scripts/build-service.ps1 customer-service -Image` |

| Endpoint | Purpose |
|---|---|
| `GET /actuator/health/liveness` | liveness probe |
| `GET /actuator/health/readiness` | readiness probe (includes the database) |
| `GET /actuator/prometheus` | metrics |

Port: `8085` (`PORT`). Configuration: `src/main/resources/application.yml` (environment
variables `DB_URL`, `DB_USER`, `DB_PASSWORD`, `PORT`).

## Integration

- Publishes: CustomerRegistered, CustomerContactChanged
- Consumes: —
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
