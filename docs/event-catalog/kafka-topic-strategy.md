# Kafka topic strategy

Status: **planned**. No broker or topic exists. Decision: ADR-0008. Declarations will live
in `infrastructure/kafka/` (CF-005).

## Topic inventory

| Topic | Producer | Message types | Keys | Consumers (groups) |
|---|---|---|---|---|
| `cf.product.events.v1` | product (Debezium) | ProductCreated, ProductUpdated, ProductDiscontinued | productId | pricing-service, inventory-service, catalog read model (owner open) |
| `cf.price.events.v1` | pricing | ProductPriceChanged | sku | catalog read model |
| `cf.customer.events.v1` | customer | CustomerRegistered, CustomerContactChanged | customerId | notification-service |
| `cf.order.events.v1` | order | OrderCreated, OrderConfirmed, OrderRejected, OrderCancelled | orderId | inventory-service, payment-service, shipping-service, notification-service |
| `cf.inventory.events.v1` | inventory | StockReserved, StockReservationFailed, StockReleased (key orderId), StockLevelChanged (key sku) | orderId / sku | order-service, catalog read model |
| `cf.payment.events.v1` | payment | PaymentAuthorized, PaymentFailed, PaymentVoided, PaymentRefunded | orderId | order-service, notification-service |
| `cf.shipment.events.v1` | shipping | ShipmentCreated, ShipmentDispatched, ShipmentDelivered | orderId | order-service, notification-service |
| `cf.inventory.commands.v1` | order | ReserveInventory, ReleaseInventory | orderId | inventory-service |
| `cf.payment.commands.v1` | order | AuthorizePayment, VoidPayment | orderId | payment-service |
| `<topic>.<consumer>.dlt` | each consumer | failed records (original bytes) | original key | humans / replay tooling |

## Why one topic per aggregate family (not per event type)

| Option | Pro | Con | Chosen |
|---|---|---|---|
| Topic per aggregate, several event types | All facts about one aggregate stay ordered by key; fewer topics | Consumers skip types they do not need; needs `TopicRecordNameStrategy` | **yes** |
| Topic per event type | Simple subscriptions | Loses ordering between e.g. `OrderConfirmed` and `OrderCancelled` of the same order | no |

Mixed keys on `cf.inventory.events.v1` (orderId for saga replies, sku for stock levels)
are acceptable because no consumer needs ordering between those two families. If that
changes, `StockLevelChanged` moves to its own topic (a major change).

## Keys and partitions

- Key = aggregate ID as string; never null for domain events.
- Partition count is fixed per topic at creation. It caps consumer parallelism per group.
  Increasing partitions later changes key-to-partition mapping (ordering breaks for keys
  in flight), so it is treated as a planned operation.
- **Partition counts are not defined yet.** They will be chosen from measured throughput
  (`performance-testing`); the skills' example value is a placeholder, not a target.

## Configuration principles

| Setting | Principle | Values |
|---|---|---|
| `cleanup.policy` | `delete` for events and commands (they are a log of facts, not a key-value state) | — |
| Retention | Long enough for replay and consumer outages | proposed defaults in data-retention-policy.md |
| `min.insync.replicas` / replication factor | Durability against broker loss in clusters | set per environment (CF-004); 1 locally |
| Auto topic creation | disabled | topics are declared in git |
| Compression | producer default (Debezium) | revisit with measurements |

## Consumer groups

One group per consuming service; scaling by adding instances up to the partition count.
Offsets are committed only after the consumer's database transaction commits
(`kafka-event-driven` skill). New consumers start from `earliest`.

## Access control (planned)

Producers: only Kafka Connect writes to `cf.*.events.*`/`cf.*.commands.*` topics (the
outbox path); DLT topics are written by their consumer. ACLs per service principal once
authentication on the broker is configured (security-architecture.md).
