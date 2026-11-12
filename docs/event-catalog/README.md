# Event Catalog — index

Status: **planned**. No schema files exist in `contracts/events/` yet; nothing is
produced or consumed today.

This folder holds the event architecture. The table below is the **machine-readable
summary** (parsed by `scripts/affected-components.ps1`; keep the column order). Full
per-event definitions — schema, key, version, delivery, idempotency and failure handling —
are in [event-catalog.md](event-catalog.md).

| Document | Content |
|---|---|
| [event-driven-architecture.md](event-driven-architecture.md) | Why and how CommerceFlow integrates through events |
| [event-catalog.md](event-catalog.md) | Detailed definition of every event and command |
| [event-naming-conventions.md](event-naming-conventions.md) | Event, command, topic, subject and header names |
| [event-versioning-policy.md](event-versioning-policy.md) | Compatibility, versions, deprecation, rollout order |
| [outbox-design.md](outbox-design.md) | Transactional outbox table and write path |
| [debezium-design.md](debezium-design.md) | CDC connectors, replication slots, recovery |
| [kafka-topic-strategy.md](kafka-topic-strategy.md) | Topics, keys, partitions, retention, consumer groups |
| [retry-and-dlq-strategy.md](retry-and-dlq-strategy.md) | Error classes, retries, dead-letter topics, replay |

## Facts (events)

| Event | Topic | Producer | Consumers |
|---|---|---|---|
| ProductCreated | `cf.product.events.v1` | product | pricing, inventory, catalog read model |
| ProductUpdated | `cf.product.events.v1` | product | catalog read model |
| ProductDiscontinued | `cf.product.events.v1` | product | pricing, inventory, catalog read model |
| ProductPriceChanged | `cf.price.events.v1` | pricing | catalog read model |
| CustomerRegistered | `cf.customer.events.v1` | customer | notification |
| CustomerContactChanged | `cf.customer.events.v1` | customer | notification |
| OrderCreated | `cf.order.events.v1` | order | notification |
| OrderConfirmed | `cf.order.events.v1` | order | inventory, shipping, notification |
| OrderRejected | `cf.order.events.v1` | order | notification |
| OrderCancelled | `cf.order.events.v1` | order | inventory, payment, shipping, notification |
| StockReserved | `cf.inventory.events.v1` | inventory | order |
| StockReservationFailed | `cf.inventory.events.v1` | inventory | order |
| StockReleased | `cf.inventory.events.v1` | inventory | order |
| StockLevelChanged | `cf.inventory.events.v1` | inventory | catalog read model |
| PaymentAuthorized | `cf.payment.events.v1` | payment | order |
| PaymentFailed | `cf.payment.events.v1` | payment | order, notification |
| PaymentVoided | `cf.payment.events.v1` | payment | order |
| PaymentRefunded | `cf.payment.events.v1` | payment | order, notification |
| ShipmentCreated | `cf.shipment.events.v1` | shipping | order |
| ShipmentDispatched | `cf.shipment.events.v1` | shipping | order, notification |
| ShipmentDelivered | `cf.shipment.events.v1` | shipping | order, notification |

The 14 events of the core catalogue (event-catalog.md, section 2) are defined in full.
The others (ProductDiscontinued, Customer*, OrderRejected, StockLevelChanged,
PaymentVoided, ShipmentDispatched) are needed by the saga and notifications and are
summarised in event-catalog.md, section 3.

"catalog read model" has no owning service yet (CF-015).

## Saga commands

| Command | Topic | Sender | Handler |
|---|---|---|---|
| ReserveInventory | `cf.inventory.commands.v1` | order | inventory |
| ReleaseInventory | `cf.inventory.commands.v1` | order | inventory |
| AuthorizePayment | `cf.payment.commands.v1` | order | payment |
| VoidPayment | `cf.payment.commands.v1` | order | payment |
