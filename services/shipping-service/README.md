# shipping-service

Fulfilment bounded context of CommerceFlow. Shipments, carrier integration adapter and tracking status.

## Status

**Buildable scaffold.** Go service with structured logging, configuration from the
environment, a lazy pgx pool, `/healthz` and `/readyz`, graceful shutdown, a migration
baseline (outbox, inbox), unit tests and a Testcontainers
integration test. No business logic or Kafka integration yet.

## Stack

Go 1.23 modules, pgx v5, `log/slog`, PostgreSQL (`shipping_db`), Go testing,
Testcontainers for Go.

## Local development

From this folder (needs Go; without Go, use `powershell -File scripts/test-service.ps1 shipping-service`
from the repo root, which runs Go in Docker):

| Task | Command |
|---|---|
| Lint | `make lint` |
| Unit tests | `make test` |
| Integration tests (Docker) | `make integration` |
| Build | `make build` |
| Run | `DATABASE_URL=postgres://user:pass@localhost:5432/shipping_db go run ./cmd/shipping-service` |
| Image | from the repo root: `powershell -File scripts/build-service.ps1 shipping-service -Image` |

| Endpoint | Purpose |
|---|---|
| `GET /healthz` | liveness (process is running) |
| `GET /readyz` | readiness (database reachable) |

Configuration: `HTTP_ADDR` (default `:8087`), `DATABASE_URL` (required),
`SHUTDOWN_TIMEOUT` (default `20s`), `LOG_LEVEL` (`debug|info|warn|error`).

Migrations: `migrations/` (golang-migrate format); applied by a migration job, not by the
service binary (`docs/architecture/migration-strategy.md`).

## Integration

- Publishes: ShipmentCreated, ShipmentDispatched, ShipmentDelivered
- Consumes: OrderConfirmed, OrderCancelled
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
