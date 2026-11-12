# shipping-service — Claude Code guide

Read the root `CLAUDE.md` first. This folder is one independently deployable service
inside the CommerceFlow monorepo.

## Bounded context: Fulfilment

Shipments, carrier integration adapter and tracking status.

This service is the only owner of its database `shipping_db`. No other service reads it, and
this service reads no other service's database.

## Independence

- Build: its own Go module and Makefile, run from this folder (`make build test`). Nothing outside this folder is compiled into it except code generated
  from `contracts/`.
- Never import, reference or copy code from another folder under `services/` or
  `apps/`. If you need behaviour from another context, use its events or API.
- Its own tests must pass when run from this folder alone.

## Messaging

- Publishes (through the transactional outbox + Debezium): ShipmentCreated, ShipmentDispatched, ShipmentDelivered
- Consumes (through the inbox, idempotently): OrderConfirmed, OrderCancelled
- Never define event schemas here; change `contracts/events/` instead.

## Layout (Clean Architecture)

```
cmd/shipping-service/main.go             composition root: config, logger, pool, HTTP server, graceful shutdown
internal/domain/               entities, value objects, events, repository interfaces (stdlib only)
internal/application/          use cases + port interfaces
internal/infrastructure/       config, logging, postgres (pgx), later kafka, outbox, inbox
internal/transport/http/       HTTP handlers (health, readiness, later API)
migrations/                    golang-migrate SQL (000001 = outbox + inbox)
tests/integration/             Testcontainers tests (build tag "integration")
go.mod, Makefile               own module and build (no go.work, no replace to siblings)
Dockerfile
```

Build: `make lint test build`; integration: `make integration`. Follow the
`golang-development` and `clean-architecture` skills; `infrastructure`/`transport` here are
what the skills call `adapters`.

## Rules

- `domain` has no framework, database or Kafka imports.
- State change + outbox row in one transaction. No direct Kafka publish from use cases.
- Inbox insert + side effects in one transaction; duplicates are skipped.
- Propagate OpenTelemetry trace context over HTTP and Kafka headers.
- Tests: unit tests for domain, Testcontainers for adapters, Pact for HTTP APIs used by
  apps or other services.
- Run the build and tests before reporting that something works.

## Status

Buildable scaffold — health/readiness, graceful shutdown, migrations baseline, tests. No business logic yet.
