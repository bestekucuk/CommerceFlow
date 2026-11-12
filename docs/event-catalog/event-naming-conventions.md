# Event naming conventions

Status: **planned** — conventions apply to the first schemas (CF-002).

## Messages

| Item | Convention | Examples |
|---|---|---|
| Domain event | `<Aggregate or subject><PastTenseVerb>`, PascalCase | `OrderCreated`, `StockReserved`, `ProductPriceChanged` |
| Saga command | `<ImperativeVerb><Object>` | `ReserveInventory`, `VoidPayment` |
| Reply event | a domain event of the handler's context | `StockReservationFailed`, `PaymentVoided` |
| Avoid | technical verbs (`OrderRowInserted`), CRUD-only names when a business verb exists (`OrderUpdated` instead of `OrderConfirmed`), "Event" suffix | — |

Business outcomes that are not errors are events too (`StockReservationFailed`,
`PaymentFailed`).

## Schemas

| Item | Convention | Example |
|---|---|---|
| File | `contracts/events/<aggregate>/<Name>.v<major>.avsc` | `contracts/events/order/OrderCreated.v1.avsc` |
| Avro namespace | `com.commerceflow.events.<aggregate>` | `com.commerceflow.events.order` |
| Avro record name | the message name | `OrderCreated` |
| Shared types | `com.commerceflow.events.common` | `EventMetadata`, `Money` |
| Field names | camelCase; IDs end in `Id`; times end in `At` | `orderId`, `occurredAt` |
| Enums | UPPER_SNAKE symbols; always include `UNKNOWN` and set it as `default` | `DECLINED`, `UNKNOWN` |

Aggregate folder names: `product`, `price`, `customer`, `order`, `inventory`, `payment`,
`shipment`, `common`.

## Topics

| Kind | Pattern | Examples |
|---|---|---|
| Events | `cf.<aggregate>.events.v<major>` | `cf.order.events.v1`, `cf.price.events.v1` |
| Commands | `cf.<aggregate>.commands.v<major>` (aggregate of the **handler**) | `cf.inventory.commands.v1` |
| Dead letters | `<source topic>.<consumer service>.dlt` | `cf.order.events.v1.shipping-service.dlt` |

Lower case, dot-separated; no environment name in topics (environments are separate
clusters or prefixes decided with CF-004).

## Schema Registry subjects

`TopicRecordNameStrategy`: `<topic>-<namespace>.<record>`, e.g.
`cf.order.events.v1-com.commerceflow.events.order.OrderCreated`.

## Kafka headers

| Header | Value | Set by |
|---|---|---|
| `id` | `eventId` (uuid) | Debezium from `outbox.id` |
| `eventType` | message name | Debezium from `outbox.type` |
| `aggregateType` | aggregate folder name | Debezium from `outbox.aggregate_type` |
| `traceparent` | W3C trace context | Debezium from `outbox.trace_parent` |
| `dlt-*` / `kafka_dlt-*` | diagnostic data | DLT publishers only |

## Consumer groups

Group id = consuming service name: `inventory-service`, `order-service`. A service with
several independent handlers uses the same group and distinguishes handlers by the
`consumer` column in its inbox.
