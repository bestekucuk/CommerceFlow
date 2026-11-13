# pricing-service

Pricing bounded context of CommerceFlow. Base prices, price lists, promotions and price quotes.

## Status

**MVP API implemented** (2026-11-12): prices per SKU with optimistic concurrency and price
quotes (`contracts/openapi/pricing-service.v1.yaml`). Tests: domain and use-case unit tests,
ArchUnit, Testcontainers API tests. Not yet: ProductCreated consumer and ProductPriceChanged
via the outbox (CF-052), Redis cache, authentication (CF-068).

## Stack

Kotlin 2.0, Spring Boot 3.3, Gradle Kotlin DSL (wrapper in this folder), Flyway,
PostgreSQL (`pricing_db`), JUnit 5, ArchUnit, Testcontainers. Bytecode target: Java 17.

## Local development

From this folder (Windows: `gradlew.bat`):

| Task | Command |
|---|---|
| Build + unit tests | `./gradlew build` |
| Integration tests (Docker) | `./gradlew integrationTest` |
| Run | `DB_URL=jdbc:postgresql://localhost:15432/pricing_db DB_USER=... DB_PASSWORD=... ./gradlew bootRun` |
| Image | from the repo root: `powershell -File scripts/build-service.ps1 pricing-service -Image` |

| Endpoint | Purpose |
|---|---|
| `GET /actuator/health/liveness` | liveness probe |
| `GET /actuator/health/readiness` | readiness probe (includes the database) |
| `GET /actuator/prometheus` | metrics |
| `GET /v1/prices?sku=A&sku=B` | current prices of several SKUs |
| `GET /v1/prices/{sku}` | one price; `ETag` = version |
| `PUT /v1/prices/{sku}` | create (201) or update with `If-Match` (200; 428 without, 412 stale) |
| `POST /v1/quotes` | price a basket; stored, valid for `QUOTE_TTL` (default 15 min) |
| `GET /v1/quotes/{id}` | read a stored quote |

Port: `8086` (`PORT`). Configuration: `src/main/resources/application.yml` (environment
variables `DB_URL`, `DB_USER`, `DB_PASSWORD`, `PORT`, `QUOTE_TTL`).

## Integration

- Publishes: ProductPriceChanged
- Consumes: ProductCreated, ProductDiscontinued
- Redis: Price lookup cache

Contracts: `contracts/events/`, `contracts/openapi/pricing-service.v1.yaml`. Event catalog: `docs/event-catalog/README.md`.
