# CommerceFlow Architecture Overview

Status: **draft**. Describes the target architecture; nothing here is implemented yet.

## Goals

- Independent deployability of each bounded context. The code lives in one modular
  monorepo (ADR-0004), but every service builds, tests, deploys and scales on its own —
  a monorepo, not a monolith.
- No distributed transactions; consistency across services through events and sagas.
- At-least-once delivery everywhere, with idempotent processing.
- End-to-end traceability of a request across HTTP and Kafka.

## Bounded contexts and context map

| Context | Service | Upstream of | Downstream of |
|---|---|---|---|
| Catalog | product-service | Pricing, Inventory, Storefront | — |
| Customer | customer-service | Ordering, Notification | — |
| Pricing | pricing-service | Ordering, Storefront | Catalog |
| Inventory | inventory-service | Ordering (saga replies) | Catalog, Ordering (commands) |
| Ordering | order-service | Inventory, Payments, Fulfilment, Notification | Customer, Pricing |
| Payments | payment-service | Ordering (saga replies) | Ordering (commands) |
| Fulfilment | shipping-service | Ordering, Notification | Ordering |
| Notification | notification-service | — | Ordering, Customer, Fulfilment, Payments |

Relationships are customer/supplier through published events (published language =
Avro contracts in `contracts/events/`). Downstream contexts keep local projections of the
upstream data they need (e.g. inventory keeps a SKU list from `ProductCreated`) and never
query upstream databases.

## Service anatomy (Clean Architecture)

```
adapters/in  (REST, Kafka listeners + inbox)
      │
application  (use cases, ports)
      │
domain       (aggregates, value objects, domain events — no framework code)
      ▲
adapters/out (PostgreSQL repositories, outbox writer, HTTP clients, Redis)
```

Dependencies point inward. Frameworks (Spring, Kafka clients, SQL drivers) appear only in
adapters and configuration.

## Data

- **Database per service**: each service has its own PostgreSQL database and credentials.
  No cross-database joins or foreign keys.
- **Redis** is a cache or read model only, never a source of truth: pricing lookups,
  catalog read model, storefront sessions.

## Messaging

- Kafka with Schema Registry (Avro). Topic per aggregate:
  `cf.<aggregate>.events.v<major>` for facts and `cf.<aggregate>.commands.v<major>` for
  saga commands. Message key = aggregate ID.
- **Transactional outbox**: services write events to an `outbox` table in the same
  transaction as the state change.
- **Change Data Capture**: Debezium reads the outbox via PostgreSQL logical replication
  and publishes with the Outbox Event Router.
- **Inbox pattern / idempotent consumers**: consumers record each message ID in an
  `inbox` table in the same transaction as their side effects and skip duplicates.
- Dead-letter topics per consumer after bounded retries.

See the `transactional-outbox` and `idempotent-consumer` skills (`.claude/skills/`) for table shapes.

## Order saga (orchestrated by order-service)

```
Storefront ──POST /orders──▶ order-service: Order PENDING, emits OrderPlaced
order-service ──ReserveInventory──▶ inventory-service
   ├─ InventoryReserved ──▶ order-service ──AuthorizePayment──▶ payment-service
   │     ├─ PaymentAuthorized ──▶ order-service: Order CONFIRMED, emits OrderConfirmed
   │     │        └──▶ shipping-service: creates shipment, emits ShipmentCreated
   │     └─ PaymentFailed ──▶ order-service ──ReleaseInventory──▶ inventory-service
   │                          Order REJECTED, emits OrderRejected
   └─ InventoryReservationFailed ──▶ order-service: Order REJECTED, emits OrderRejected
notification-service consumes OrderConfirmed, OrderCancelled, OrderRejected,
ShipmentDispatched, PaymentFailed → sends customer notifications
```

`OrderRejected` ends a saga that never confirmed (compensation is done by explicit
commands). `OrderCancelled` is reserved for cancelling a **confirmed** order; inventory,
payment and shipping react to it by releasing stock, refunding and stopping shipment.

Saga state is persisted in the order-service database. Every step has a timeout; a
timed-out step triggers the same compensation as a failure. Commands are published
through the outbox like events.

## CQRS (where justified)

- **Catalog search/browse**: storefront reads a denormalized read model (product +
  current price + availability flag) built from events, separate from the catalog write
  model. Location to be decided (ADR pending).
- **Order history**: customer-facing order history projection in order-service.

Other services use a single model.

## Observability

- OpenTelemetry SDKs in every service; W3C `traceparent` propagated over HTTP and copied
  into Kafka headers (and the outbox row) so traces survive asynchronous hops.
- OpenTelemetry Collector → Tempo (traces), Prometheus (metrics), Loki (logs);
  Grafana for dashboards.
- Log lines include `trace_id` and `span_id`.

## Deployment

- Local: root `docker-compose.yml`, with component configuration under
  `infrastructure/{docker,postgres,kafka,debezium,redis,monitoring}/`.
- Cluster: Kubernetes manifests and Helm charts in `infrastructure/kubernetes/`, one
  release per service plus platform components (Kafka, Schema Registry, Debezium/Kafka
  Connect, PostgreSQL, Redis, observability).
- Cloud resources: Terraform; location and provider to be decided (CF-004).
- Each service has its own container image and CI pipeline, triggered only by changes
  under its own folder or the contracts it uses (CF-020).

## Open questions

Tracked in `backlog/BACKLOG.md` (items tagged `decision`).
