# Communication patterns

Status: **planned**. Patterns are decided (ADR-0006–0010); no messages flow yet.

## Choosing a pattern

| Need | Pattern | Example |
|---|---|---|
| Tell others a fact happened | Event via outbox → Debezium → Kafka | `ProductCreated` |
| Ask one service to do something as part of a coordinated process | Saga command via outbox, reply event | `ReserveInventory` → `StockReserved` |
| Read fresh data owned by another service, synchronously | HTTP API (OpenAPI), with timeout and fallback | price quote at checkout |
| UI reads and writes | HTTP through gateway (and admin BFF) | storefront order history |

Synchronous chains are limited to depth one (caller → owner). Events never require the
consumer to call back the producer to understand them.

## Product creation CDC flow

```mermaid
sequenceDiagram
    autonumber
    actor Staff
    participant Admin as admin-web / BFF
    participant PS as product-service
    participant DB as product_db
    participant DBZ as Debezium connector
    participant K as Kafka cf.product.events.v1
    participant INV as inventory-service
    participant PR as pricing-service

    Staff->>Admin: create product
    Admin->>PS: POST /v1/products
    PS->>DB: one tx — INSERT product + sku, INSERT outbox(ProductCreated), COMMIT
    PS-->>Admin: 201 Created
    DBZ->>DB: read WAL (slot cf_product_slot)
    DBZ->>K: key=productId, headers id/eventType/traceparent, value=Avro bytes
    par consumers in their own groups
        K->>INV: ProductCreated
        INV->>INV: inbox + create stock_item (0 on hand) in one tx
    and
        K->>PR: ProductCreated
        PR->>PR: inbox + register SKU for pricing in one tx
    end
```

## Order saga

```mermaid
sequenceDiagram
    autonumber
    actor C as Customer
    participant O as order-service
    participant I as inventory-service
    participant P as payment-service
    participant S as shipping-service
    participant N as notification-service

    C->>O: POST /v1/orders (Idempotency-Key)
    O->>O: tx: order PENDING, saga AWAITING_STOCK, outbox OrderCreated + ReserveInventory
    O-->>C: 202 Accepted
    O-)N: OrderCreated
    O-)I: ReserveInventory
    alt stock available
        I-)O: StockReserved
        O->>O: tx: saga AWAITING_PAYMENT, outbox AuthorizePayment
        O-)P: AuthorizePayment
        alt authorized
            P-)O: PaymentAuthorized
            O->>O: tx: order CONFIRMED, outbox OrderConfirmed
            O-)I: OrderConfirmed (commit reservation)
            O-)S: OrderConfirmed (create shipment)
            O-)N: OrderConfirmed
        else declined or timeout
            P-)O: PaymentFailed / timeout fired
            Note over O,I: compensation — see payment compensation
        end
    else insufficient stock or timeout
        I-)O: StockReservationFailed / timeout fired
        O->>O: tx: order REJECTED, outbox OrderRejected (and ReleaseInventory on timeout)
        O-)N: OrderRejected
    end
```

State machine (order-service):

```mermaid
stateDiagram-v2
    [*] --> AWAITING_STOCK: OrderCreated
    AWAITING_STOCK --> AWAITING_PAYMENT: StockReserved
    AWAITING_STOCK --> REJECTED: StockReservationFailed
    AWAITING_STOCK --> COMPENSATING: timeout (ReleaseInventory)
    AWAITING_PAYMENT --> CONFIRMED: PaymentAuthorized
    AWAITING_PAYMENT --> COMPENSATING: PaymentFailed (ReleaseInventory)
    AWAITING_PAYMENT --> COMPENSATING: timeout (VoidPayment + ReleaseInventory)
    COMPENSATING --> REJECTED: all compensations acknowledged
    CONFIRMED --> [*]
    REJECTED --> [*]
```

## Payment compensation

```mermaid
sequenceDiagram
    autonumber
    participant O as order-service
    participant P as payment-service
    participant PSP as payment provider
    participant I as inventory-service

    O-)P: AuthorizePayment
    Note over O: deadline passes, no reply
    O->>O: tx: saga COMPENSATING, outbox VoidPayment + ReleaseInventory
    O-)P: VoidPayment
    O-)I: ReleaseInventory
    alt authorization had succeeded late
        P->>PSP: void authorization
        P-)O: PaymentVoided
    else nothing was authorized
        P-)O: PaymentVoided (no-op, still replied)
    end
    I-)O: StockReleased
    Note over O: late PaymentAuthorized for this order is ignored (state check)
    O->>O: tx: order REJECTED, outbox OrderRejected
```

Cancellation of a **confirmed** order is not a compensation: order-service emits
`OrderCancelled`; payment-service refunds (`PaymentRefunded`), inventory releases or
restocks, shipping stops the shipment if not yet dispatched.

## Synchronous calls (justified list)

| Caller | Callee | Call | Why synchronous | Failure behaviour |
|---|---|---|---|---|
| order-service | pricing-service | price quote for order lines | The customer must see and accept the final price before the order is created | Order creation fails with 503; nothing persisted |
| order-service | customer-service | validate customer and default address | Needed to create a valid order | 503; or use address supplied in request |
| admin BFF | any service API | composed reads | UI composition | Partial view with per-section errors |

Timeout and retry values are not defined yet; they are set per call from measurements.

## Related

[../event-catalog/event-driven-architecture.md](../event-catalog/event-driven-architecture.md) ·
ADR-0009 · `saga-pattern` skill
