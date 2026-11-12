# inventory-service

Inventory bounded context of CommerceFlow. Stock levels per SKU and location, reservations with expiry.

## Status

ProductCreated consumer and stock read API implemented (see `CLAUDE.md` for scope).
Reservations and the other consumed events are not implemented yet.

## Stack

Go 1.23 modules, pgx v5, `log/slog`, PostgreSQL (`inventory_db`), Go testing,
Testcontainers for Go.

## Local development

From this folder (needs Go; without Go, use `powershell -File scripts/test-service.ps1 inventory-service`
from the repo root, which runs Go in Docker):

| Task | Command |
|---|---|
| Lint | `make lint` |
| Unit tests | `make test` |
| Integration tests (Docker) | `make integration` |
| Build | `make build` |
| Run | `DATABASE_URL=postgres://user:pass@localhost:15432/inventory_db go run ./cmd/inventory-service` |
| Image | from the repo root: `powershell -File scripts/build-service.ps1 inventory-service -Image` |

| Endpoint | Purpose |
|---|---|
| `GET /healthz` | liveness (process is running) |
| `GET /readyz` | readiness (database reachable and consumer not stuck retrying) |
| `GET /metrics` | Prometheus metrics |
| `GET /v1/stock/{sku}` | stock item read |

Readiness choice: while the consumer is retrying a transient failure (for example the database
is unreachable), `/readyz` reports DOWN, so the pod is taken out of HTTP load balancing but
not restarted (`/healthz` stays UP). The partition is not skipped: ordering and the inbox
guarantee are kept, and processing resumes when the dependency recovers. Retries are visible
as `commerceflow_message_retries_total`; an alert rule is planned (CF-079).

Configuration: `HTTP_ADDR` (default `:8083`), `DATABASE_URL`, `KAFKA_BROKERS`, `SCHEMA_REGISTRY_URL` (required),
`OTEL_EXPORTER_OTLP_ENDPOINT` (optional),
`SHUTDOWN_TIMEOUT` (default `20s`), `LOG_LEVEL` (`debug|info|warn|error`).

Migrations: `migrations/` (golang-migrate format); applied by a migration job, not by the
service binary (`docs/architecture/migration-strategy.md`).

## Integration

- Publishes: StockReserved, StockReservationFailed, StockReleased, StockLevelChanged
- Consumes: Commands ReserveInventory, ReleaseInventory; ProductCreated, ProductDiscontinued, OrderConfirmed, OrderCancelled
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
