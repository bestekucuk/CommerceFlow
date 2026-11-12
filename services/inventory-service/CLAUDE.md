# inventory-service — Claude Code guide

Read the root `CLAUDE.md` first. This folder is one independently deployable service
inside the CommerceFlow monorepo.

## Bounded context: Inventory

Stock levels per SKU and location, reservations with expiry.

This service is the only owner of its database `inventory_db`. No other service reads it, and
this service reads no other service's database.

## Independence

- Build: its own Go module and Makefile, run from this folder (`make build test`). Nothing outside this folder is compiled into it except code generated
  from `contracts/`.
- Never import, reference or copy code from another folder under `services/` or
  `apps/`. If you need behaviour from another context, use its events or API.
- Its own tests must pass when run from this folder alone.

## Messaging

- Publishes (through the transactional outbox + Debezium): InventoryReserved, InventoryReservationFailed, InventoryReleased, StockLevelChanged
- Consumes (through the inbox, idempotently): Commands ReserveInventory, ReleaseInventory; ProductCreated, ProductDiscontinued, OrderCancelled
- Never define event schemas here; change `contracts/events/` instead.

## Planned layout (Clean Architecture)

```
cmd/inventory-service/main.go
internal/domain/        entities, value objects, events, repository interfaces
internal/application/   use cases
internal/adapters/      http, kafka (consumer + inbox), postgres (repositories + outbox), redis
internal/platform/      config, logging (slog), telemetry (OpenTelemetry)
migrations/             SQL migrations (outbox, inbox, domain tables)
go.mod, Makefile        own module and build
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
