# Event catalogue (detailed)

Status: **planned**. These are the agreed definitions for the first Avro schemas (CF-002).
No `.avsc` file, topic or producer exists yet. The summary table used by tooling is in
[README.md](README.md).

## 1. Rules that apply to every event

| Aspect | Rule |
|---|---|
| Envelope | Every record has `metadata: EventMetadata` (`eventId` uuid, `eventType`, `aggregateId`, `occurredAt` timestamp-millis, `correlationId`, `causationId` nullable, `producer`) — `contracts/events/README.md` |
| Money | `Money { amountMinor: long, currency: string (ISO 4217) }` |
| Encoding | Avro, Confluent wire format, subject `TopicRecordNameStrategy`, compatibility `BACKWARD` |
| Publishing | Written to the producer's `outbox` in the business transaction; relayed by Debezium ([outbox-design.md](outbox-design.md), [debezium-design.md](debezium-design.md)) |
| Kafka key | the aggregate key listed per event → ordering per aggregate only |
| Headers | `id` (= `eventId`), `eventType`, `traceparent`, `aggregateType` |
| Delivery semantics | **At-least-once**. Duplicates occur after connector restarts and consumer rebalances; ordering is guaranteed only within one key |
| Idempotency (default) | Consumer inserts `(eventId, consumer)` into its `inbox` in the same transaction as its effects; duplicates are skipped. Per-event natural idempotency is listed below as a second line of defence |
| Failure handling (default) | Transient errors: bounded blocking retries with backoff. Permanent errors (deserialization, validation, unknown required data): `<topic>.<consumer>.dlt` with diagnostic headers, alert, fix, replay ([retry-and-dlq-strategy.md](retry-and-dlq-strategy.md)) |
| Version | All events start at **v1** (file `<Event>.v1.avsc`, topic suffix `.v1`) |

Schemas below list payload fields after `metadata`. `?` = optional (union with null,
default null). Types: `uuid` = string with logicalType uuid; `ts` = long
timestamp-millis.

## 2. Core events

### 2.1 ProductCreated

| Aspect | Value |
|---|---|
| Producer | product-service |
| Consumers | pricing-service (register SKUs for pricing), inventory-service (create stock items with zero stock), catalog read model (owner open, CF-015) |
| Topic | `cf.product.events.v1` |
| Aggregate key | `productId` |
| Version | v1 |
| Delivery | at-least-once, ordered per product |
| Idempotency | inbox; natural: insert projection `ON CONFLICT (product_id) DO NOTHING` |
| Failure handling | default; a consumer missing a referenced category is not an error (IDs only) |

```text
productId: uuid
skus: array<record Sku { sku: string, name: string }>
name: string
categoryId: uuid?
status: enum ProductStatus { DRAFT, ACTIVE, UNKNOWN } default UNKNOWN
```

### 2.2 ProductUpdated

| Aspect | Value |
|---|---|
| Producer | product-service |
| Consumers | catalog read model |
| Topic | `cf.product.events.v1` |
| Aggregate key | `productId` |
| Version | v1 |
| Delivery | at-least-once, ordered per product |
| Idempotency | inbox; natural: apply only if `productVersion` > stored version (out-of-order safe) |
| Failure handling | default |

```text
productId: uuid
productVersion: long          # aggregate version after the change
name: string?
description: string?
categoryId: uuid?
status: enum ProductStatus?
changedFields: array<string>  # names of fields that changed
```

### 2.3 ProductPriceChanged

| Aspect | Value |
|---|---|
| Producer | pricing-service (owner of prices; the name refers to the product's price) |
| Consumers | catalog read model |
| Topic | `cf.price.events.v1` |
| Aggregate key | `sku` |
| Version | v1 |
| Delivery | at-least-once, ordered per SKU |
| Idempotency | inbox; natural: keep the row with the highest `priceVersion` |
| Failure handling | default |

```text
sku: string
priceListId: uuid
priceVersion: long
price: Money
validFrom: ts
validUntil: ts?
```

Order-service does **not** consume this event: the binding price is the quote taken
synchronously at order creation (communication-patterns.md).

### 2.4 StockReserved

| Aspect | Value |
|---|---|
| Producer | inventory-service (reply to `ReserveInventory`) |
| Consumers | order-service (saga) |
| Topic | `cf.inventory.events.v1` |
| Aggregate key | `orderId` (the saga correlation; keeps all replies for one order in order) |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: saga transition only from `AWAITING_STOCK` |
| Failure handling | default; a reply for an unknown or already-finished saga is acknowledged and ignored |

```text
orderId: uuid
reservationId: uuid
lines: array<record ReservedLine { sku: string, quantity: int }>
expiresAt: ts
```

### 2.5 StockReservationFailed

| Aspect | Value |
|---|---|
| Producer | inventory-service |
| Consumers | order-service (saga) |
| Topic | `cf.inventory.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: transition only from `AWAITING_STOCK` |
| Failure handling | default. This is a business outcome, not an error |

```text
orderId: uuid
reason: enum StockFailureReason { INSUFFICIENT_STOCK, UNKNOWN_SKU, SKU_DISCONTINUED, UNKNOWN } default UNKNOWN
unavailable: array<record UnavailableLine { sku: string, requested: int, available: int }>
```

### 2.6 StockReleased

| Aspect | Value |
|---|---|
| Producer | inventory-service (reply to `ReleaseInventory`, or after `OrderCancelled`) |
| Consumers | order-service |
| Topic | `cf.inventory.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: release only `ACTIVE` reservations; always reply, even if nothing was reserved |
| Failure handling | default; compensation must eventually succeed — persistent failure goes to DLT and pages |

```text
orderId: uuid
reservationId: uuid?          # null when nothing had been reserved
reason: enum ReleaseReason { SAGA_COMPENSATION, ORDER_CANCELLED, EXPIRED, UNKNOWN } default UNKNOWN
```

### 2.7 OrderCreated

| Aspect | Value |
|---|---|
| Producer | order-service |
| Consumers | notification-service ("order received") |
| Topic | `cf.order.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: unique `(event_id, channel)` on the notification row |
| Failure handling | default; non-blocking retries allowed for notification (order-independent) |

```text
orderId: uuid
customerId: uuid
lines: array<record OrderLine { sku: string, quantity: int, unitPrice: Money }>
total: Money
quoteId: uuid
```

### 2.8 OrderConfirmed

| Aspect | Value |
|---|---|
| Producer | order-service (saga pivot) |
| Consumers | inventory-service (commit reservation), shipping-service (create shipment), notification-service |
| Topic | `cf.order.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: shipment unique per `orderId`; reservation commit only from `ACTIVE` |
| Failure handling | default; a shipping DLT entry here means a paid order is not shipped → page |

```text
orderId: uuid
customerId: uuid
reservationId: uuid
paymentId: uuid
lines: array<OrderLine>
total: Money
shippingAddressId: uuid       # reference into customer-service; shipping receives the address via API or a later contract change (open)
```

### 2.9 OrderCancelled

| Aspect | Value |
|---|---|
| Producer | order-service (cancellation of a **confirmed** order) |
| Consumers | inventory-service (release/restock), payment-service (refund), shipping-service (stop shipment), notification-service |
| Topic | `cf.order.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: refund unique per `orderId`; release only `ACTIVE`/`COMMITTED` stock once |
| Failure handling | default; refund failure goes to DLT and pages (money) |

```text
orderId: uuid
reason: enum CancellationReason { CUSTOMER_REQUEST, STAFF_ACTION, FRAUD, UNKNOWN } default UNKNOWN
cancelledBy: enum Actor { CUSTOMER, STAFF, SYSTEM } default SYSTEM
```

Orders that never reached confirmation end with `OrderRejected` (section 3), not
`OrderCancelled`.

### 2.10 PaymentAuthorized

| Aspect | Value |
|---|---|
| Producer | payment-service (reply to `AuthorizePayment`) |
| Consumers | order-service (saga) |
| Topic | `cf.payment.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: transition only from `AWAITING_PAYMENT`; if the saga is already compensating, order-service sends `VoidPayment` |
| Failure handling | default |

```text
orderId: uuid
paymentId: uuid
amount: Money
providerReference: string     # opaque provider id; no card data
authorizedAt: ts
```

### 2.11 PaymentFailed

| Aspect | Value |
|---|---|
| Producer | payment-service |
| Consumers | order-service (saga), notification-service |
| Topic | `cf.payment.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: transition only from `AWAITING_PAYMENT` |
| Failure handling | default. Business outcome, not an error |

```text
orderId: uuid
paymentId: uuid
reason: enum PaymentFailureReason { DECLINED, INSUFFICIENT_FUNDS, PROVIDER_ERROR, TIMEOUT, UNKNOWN } default UNKNOWN
```

### 2.12 PaymentRefunded

| Aspect | Value |
|---|---|
| Producer | payment-service (after `OrderCancelled`) |
| Consumers | order-service (record refund), notification-service |
| Topic | `cf.payment.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: refund recorded once per `refundId` |
| Failure handling | default |

```text
orderId: uuid
paymentId: uuid
refundId: uuid
amount: Money
refundedAt: ts
```

### 2.13 ShipmentCreated

| Aspect | Value |
|---|---|
| Producer | shipping-service (after `OrderConfirmed`) |
| Consumers | order-service (order status) |
| Topic | `cf.shipment.events.v1` |
| Aggregate key | `orderId` (keeps shipment facts ordered with the order) |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: one shipment reference per order |
| Failure handling | default |

```text
orderId: uuid
shipmentId: uuid
carrier: string?              # null until a carrier is assigned
```

### 2.14 ShipmentDelivered

| Aspect | Value |
|---|---|
| Producer | shipping-service (carrier tracking) |
| Consumers | order-service (complete order), notification-service |
| Topic | `cf.shipment.events.v1` |
| Aggregate key | `orderId` |
| Version | v1 |
| Delivery | at-least-once, ordered per order |
| Idempotency | inbox; natural: status update only if not already `DELIVERED` |
| Failure handling | default; carrier webhooks may arrive late or twice — shipping deduplicates before publishing |

```text
orderId: uuid
shipmentId: uuid
deliveredAt: ts
```

## 3. Further planned events (summary)

Required by the saga and notifications; full definitions follow the same template when
their schemas are written.

| Event | Producer | Key | Purpose |
|---|---|---|---|
| ProductDiscontinued | product-service | productId | Stop pricing and selling a product |
| CustomerRegistered | customer-service | customerId | Welcome notification, contact projection |
| CustomerContactChanged | customer-service | customerId | Keep notification contacts current |
| OrderRejected | order-service | orderId | Saga ended without confirmation (stock or payment failed, timeout) |
| StockLevelChanged | inventory-service | sku | Availability for the catalog read model |
| PaymentVoided | payment-service | orderId | Reply to `VoidPayment` (also when nothing was authorized) |
| ShipmentDispatched | shipping-service | orderId | Parcel handed to carrier |

## 4. Saga commands

| Command | Topic | Key | Sender → Handler | Reply events |
|---|---|---|---|---|
| ReserveInventory | `cf.inventory.commands.v1` | orderId | order → inventory | StockReserved / StockReservationFailed |
| ReleaseInventory | `cf.inventory.commands.v1` | orderId | order → inventory | StockReleased |
| AuthorizePayment | `cf.payment.commands.v1` | orderId | order → payment | PaymentAuthorized / PaymentFailed |
| VoidPayment | `cf.payment.commands.v1` | orderId | order → payment | PaymentVoided |

Commands use the same envelope; `correlationId` = `orderId`, `causationId` = the event that
triggered the command.

## 5. Open points

- How shipping-service obtains the delivery address (API call to customer-service, or an
  address snapshot in `OrderConfirmed`; the latter puts personal data in Kafka).
- Payment capture timing (at confirmation or at dispatch) — CF-016.
- Reservation expiry duration and commit semantics — inventory design.
