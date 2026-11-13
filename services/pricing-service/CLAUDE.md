# pricing-service — Claude Code guide

Read the root `CLAUDE.md` first. This folder is one independently deployable service
inside the CommerceFlow monorepo.

## Bounded context: Pricing

Base prices, price lists, promotions and price quotes.

This service is the only owner of its database `pricing_db`. No other service reads it, and
this service reads no other service's database.

## Independence

- Build: its own Gradle Kotlin DSL build with wrapper, run from this folder (`./gradlew build`). Nothing outside this folder is compiled into it except code generated
  from `contracts/`.
- Never import, reference or copy code from another folder under `services/` or
  `apps/`. If you need behaviour from another context, use its events or API.
- Its own tests must pass when run from this folder alone.

## Messaging

- Publishes (through the transactional outbox + Debezium): ProductPriceChanged
- Consumes (through the inbox, idempotently): ProductCreated, ProductDiscontinued
- Never define event schemas here; change `contracts/events/` instead.

## Layout (Clean Architecture)

```
src/main/kotlin/com/commerceflow/pricing/
  PricingServiceApplication.kt   Spring Boot entry point
  domain/          aggregates, value objects, domain events, repository ports (no Spring)
  application/     use cases and ports; transaction boundaries
  infrastructure/  persistence, outbox writer, Kafka, HTTP clients, Spring config
  presentation/    REST controllers, DTOs, problem details
src/main/resources/application.yml
src/main/resources/db/migration/   Flyway (V1 = outbox, inbox; V2 = price, quote, quote_line)
src/test/kotlin/com/commerceflow/pricing/
  ArchitectureTest.kt      layer and cross-service rules (unit)
  ApplicationHealthIT.kt   Testcontainers, tag "integration"
build.gradle.kts, settings.gradle.kts, gradlew   own Gradle build (not part of any root build)
Dockerfile
```

Build: `./gradlew build` (unit), `./gradlew integrationTest` (Docker). Follow the
`kotlin-springboot` and `clean-architecture` skills; package names here use
`infrastructure`/`presentation` for what the skills call `adapters/out`/`adapters/in`.

## Rules

- `domain` has no framework, database or Kafka imports.
- State change + outbox row in one transaction. No direct Kafka publish from use cases.
- Inbox insert + side effects in one transaction; duplicates are skipped.
- Propagate OpenTelemetry trace context over HTTP and Kafka headers.
- Tests: unit tests for domain, Testcontainers for adapters, Pact for HTTP APIs used by
  apps or other services.
- Run the build and tests before reporting that something works.

## Status

Implemented (MVP): prices per SKU (`PUT/GET /v1/prices`, ETag/If-Match, list) and quotes
(`POST/GET /v1/quotes`, stored, TTL), Flyway V2 (`price`, `quote`, `quote_line`), problem
details, correlation id. Tests: domain + use case (unit), ArchUnit, PricingApiIT
(Testcontainers). Not yet: ProductCreated consumer, ProductPriceChanged outbox, Redis cache,
authentication (CF-068).
