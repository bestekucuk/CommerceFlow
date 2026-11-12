# Database ownership

Status: **planned**. No database, role or init script exists yet
(`infrastructure/postgres/` contains only a README). Decision: ADR-0005.

## Rules

1. One PostgreSQL database per service. Only that service's roles can connect.
2. One writer per table: the owning service.
3. No cross-database foreign keys, views, `dblink`, `postgres_fdw` or shared schemas.
4. Data needed elsewhere travels as events (consumers build projections) or through the
   owner's API.
5. Projections in a consumer database are **owned by the consumer**, rebuildable from
   events, and never written back to the source.
6. Redis keys are owned per service and prefixed `<short>:`; Redis is never a source of
   truth.

## Ownership table

| Database | Owner | Roles | Business tables (planned) | Projections (from events) | Infrastructure tables |
|---|---|---|---|---|---|
| `product_db` | product-service | product_migrator, product_service, product_cdc | product, sku, category, product_attribute | — | outbox |
| `pricing_db` | pricing-service | pricing_* | price, price_list, promotion | product_projection (ProductCreated/Discontinued) | outbox, inbox |
| `customer_db` | customer-service | customer_* | customer, address | — | outbox |
| `order_db` | order-service | order_* | customer_order, order_line, saga_instance | order_history_view (own events) | outbox, inbox, idempotency_key |
| `inventory_db` | inventory-service | inventory_* | stock_item, reservation | product_projection | outbox, inbox |
| `payment_db` | payment-service | payment_* | payment, payment_attempt | — | outbox, inbox, idempotency_key |
| `shipping_db` | shipping-service | shipping_* | shipment, tracking_event | order_projection (OrderConfirmed) | outbox, inbox |
| `notification_db` | notification-service | notification_* | notification, template, delivery_log | contact_projection (Customer* events) | inbox |

Table lists are a starting design; each service's `database-engineer` task finalises
them.

## Roles

| Role | Privileges | Used by |
|---|---|---|
| `<short>_migrator` | owns the database; DDL | Flyway / golang-migrate (Job or startup) |
| `<short>_service` | `SELECT, INSERT, UPDATE, DELETE` on tables | the service at runtime |
| `<short>_cdc` | `REPLICATION`, `SELECT` on `outbox`, write on heartbeat table | Debezium connector |

Credentials are injected from secrets; none are committed (secret detection hook).

## Physical topology

- **Local:** one PostgreSQL container hosting all eight databases, `wal_level=logical`.
  Isolation is by role and database.
- **Staging/production:** **open** (CF-004) — one instance per service, or shared
  instances with separate databases. Trade-off: separate instances isolate load,
  failures and maintenance windows; shared instances cost less but couple them.

## Who may read what

| Reader | Allowed |
|---|---|
| Owning service | its own database |
| Debezium | only the `outbox` table, via publication |
| Other services | never — use events or the owner's API |
| Analytics/reporting | not planned; would be fed by events, never by direct reads |
| Humans (support) | read-only role per database, through a controlled procedure (runbook, planned) |

## Related

[database-naming-conventions.md](database-naming-conventions.md) ·
[migration-strategy.md](migration-strategy.md) ·
[data-retention-policy.md](data-retention-policy.md) · `postgresql-design` skill
