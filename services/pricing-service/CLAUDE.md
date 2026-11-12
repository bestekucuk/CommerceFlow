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

- Publishes (through the transactional outbox + Debezium): PriceChanged
- Consumes (through the inbox, idempotently): ProductCreated, ProductDiscontinued
- Never define event schemas here; change `contracts/events/` instead.

## Planned layout (Clean Architecture)

```
src/main/kotlin/com/commerceflow/pricing/
  domain/          aggregates, value objects, domain events, repository ports (no Spring)
  application/     use cases, inbound and outbound ports
  adapters/in/     web (REST), messaging (Kafka listeners + inbox)
  adapters/out/    persistence, outbox writer, HTTP clients
  config/          Spring wiring only
src/main/resources/db/migration/   Flyway migrations (outbox, inbox, domain tables)
src/test/kotlin/com/commerceflow/pricing/   JUnit 5 unit tests, Testcontainers integration tests
build.gradle.kts, settings.gradle.kts, gradlew   own Gradle build (not part of any root build)
Dockerfile
```

Follow the `service-scaffold` skill when creating it.

## Rules

- `domain` has no framework, database or Kafka imports.
- State change + outbox row in one transaction. No direct Kafka publish from use cases.
- Inbox insert + side effects in one transaction; duplicates are skipped.
- Propagate OpenTelemetry trace context over HTTP and Kafka headers.
- Tests: unit tests for domain, Testcontainers for adapters, Pact for HTTP APIs used by
  apps or other services.
- Run the build and tests before reporting that something works.

## Status

Scaffold only — no code yet.
