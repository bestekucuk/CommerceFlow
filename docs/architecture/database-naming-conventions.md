# Database naming conventions

Status: **planned** — conventions agreed for the first migrations; no schema exists yet.

## Objects

| Object | Convention | Example |
|---|---|---|
| Database | `<short>_db` (short = service name without `-service`) | `order_db` |
| Roles | `<short>_migrator`, `<short>_service`, `<short>_cdc` | `order_cdc` |
| Schema | `public` (one service per database makes extra schemas unnecessary) | — |
| Table | singular `snake_case` noun; avoid reserved words | `customer_order` (not `order`), `order_line` |
| Column | `snake_case`; no type or table prefixes | `placed_at`, `customer_id` |
| Primary key | `id` (uuid) or a natural composite when the row has no identity of its own | `order_line (order_id, line_no)` |
| Foreign key column (same database) | `<referenced_table>_id` | `order_id` |
| Reference to another context | `<thing>_id` with **no** FK constraint | `customer_id`, `sku` |
| Timestamps | `<verb>_at`, `timestamptz`, UTC | `created_at`, `confirmed_at` |
| Booleans | `is_`/`has_` prefix | `is_active` |
| Money | `<name>_minor bigint` + `currency char(3)` | `total_minor`, `currency` |
| Status | `status text` + CHECK constraint listing allowed values | `CHECK (status IN (...))` |
| Version (optimistic lock) | `version bigint NOT NULL DEFAULT 0` | — |

## Constraints and indexes

| Kind | Pattern | Example |
|---|---|---|
| Primary key | `<table>_pkey` (PostgreSQL default) | `customer_order_pkey` |
| Unique | `<table>_<columns>_key` | `sku_code_key` |
| Foreign key | `<table>_<column>_fkey` | `order_line_order_id_fkey` |
| Check | `<table>_<rule>_chk` | `customer_order_status_chk` |
| Index | `<table>_<columns>_idx` | `customer_order_customer_placed_idx` |
| Partial index | `<table>_<purpose>_idx` | `customer_order_inflight_idx` |

## Infrastructure tables (identical in every service)

| Table | Purpose | Defined in |
|---|---|---|
| `outbox` | events and commands to publish | [../event-catalog/outbox-design.md](../event-catalog/outbox-design.md) |
| `inbox` | processed message IDs | [../event-catalog/retry-and-dlq-strategy.md](../event-catalog/retry-and-dlq-strategy.md), `idempotent-consumer` skill |
| `idempotency_key` | stored responses for HTTP idempotency keys | `rest-api-design` skill |
| `debezium_heartbeat` | keeps the replication slot advancing | [../event-catalog/debezium-design.md](../event-catalog/debezium-design.md) |
| `flyway_schema_history` / `schema_migrations` | migration tool state | tool default |

## Migration files

| Language | Location | Name |
|---|---|---|
| Kotlin (Flyway) | `services/<svc>/src/main/resources/db/migration/` | `V<n>__<snake_description>.sql`, optional `.sql.conf` |
| Go (golang-migrate) | `services/<svc>/migrations/` | `<6-digit n>_<snake_description>.up.sql` / `.down.sql` |

## Redis keys

`<short>:<purpose>:<id>`, e.g. `pricing:quote:<sku>`, `product:card:<productId>`.
Every key has a TTL unless it is a rebuildable read model with an explicit rebuild job.
