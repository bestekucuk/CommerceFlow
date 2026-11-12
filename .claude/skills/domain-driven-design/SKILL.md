---
name: domain-driven-design
description: Apply Domain-Driven Design inside a CommerceFlow bounded context - aggregates, invariants, value objects, domain events, repositories, ubiquitous language, context mapping and anti-corruption layers - and keep service-owned domain models separate from shared contracts. Use when modelling or changing domain logic in any service.
---

# Domain-Driven Design

## Purpose

Model each CommerceFlow context so that business rules live in one place, are enforced by
aggregates, and are expressed in the language of the domain. Keep the **domain model**
(private to a service) separate from the **published language** (`contracts/`).

## When to use

- Designing a new aggregate or changing an invariant.
- Deciding where a rule belongs (which aggregate, which context).
- Translating between a contract/external API and the domain model.
- Naming things: classes, events, endpoints.

## Prerequisites

- Context map in `docs/architecture/overview.md`.
- The service's `CLAUDE.md` (bounded context and owned data).
- `clean-architecture` for where domain code lives.

## Concepts and architecture

| Building block | Rule in CommerceFlow |
|---|---|
| **Aggregate** | Consistency boundary. One transaction modifies one aggregate instance. Referenced by ID from outside. |
| **Aggregate root** | Only entry point; enforces invariants; exposes intention-revealing methods (`confirm()`, not `setStatus()`). |
| **Value object** | Immutable, equality by value, validates itself (`Money`, `Sku`, `Quantity`). |
| **Domain event** | Something that happened, raised by the aggregate, mapped to a contract event in an adapter. |
| **Repository** | Port in `domain`/`application`, loads and saves whole aggregates. |
| **Domain service** | Stateless rule spanning several aggregates of the *same* context. |
| **Anti-corruption layer** | Adapter translating an external model (payment provider, carrier) into domain terms. |

Context relationships: CommerceFlow contexts are **customer/supplier** through published
events. Downstream contexts translate upstream events into their own model; they never
reuse upstream classes.

**Domain model ≠ contract.** `OrderCreated` in `contracts/events/order/` is a stable,
versioned data shape. The `Order` aggregate in `services/order-service` can change freely
as long as the adapter still produces the contract.

## Step-by-step workflow

1. Write the rule in plain language with a domain expert's words ("An order can be
   confirmed only when stock is reserved and payment is authorized").
2. Find the aggregate whose state the rule protects. If the rule spans two contexts, it is
   a saga, not an invariant (`saga-pattern`).
3. Model value objects for every concept with validation (money, quantities, IDs).
4. Add an intention-revealing method on the root that checks the invariant and records a
   domain event.
5. Keep the aggregate small: include only what the invariant needs.
6. Map domain events to contract events in an outbound adapter.
7. Add terms to the context's glossary (`services/<name>/README.md`, "Ubiquitous language").

## Practical code examples

Kotlin aggregate (order-service, `domain/`):

```kotlin
@JvmInline value class OrderId(val value: UUID)

data class Money(val amountMinor: Long, val currency: Currency) {
    init { require(amountMinor >= 0) { "Money cannot be negative" } }
    operator fun plus(other: Money): Money {
        require(currency == other.currency) { "Currency mismatch" }
        return Money(amountMinor + other.amountMinor, currency)
    }
}

data class OrderLine(val sku: Sku, val quantity: Int, val unitPrice: Money) {
    init { require(quantity > 0) }
    val total: Money get() = Money(unitPrice.amountMinor * quantity, unitPrice.currency)
}

class Order private constructor(
    val id: OrderId,
    val customerId: CustomerId,
    val lines: List<OrderLine>,
    status: OrderStatus,
) {
    var status: OrderStatus = status; private set
    private val events = mutableListOf<OrderDomainEvent>()

    fun total(): Money = lines.map { it.total }.reduce(Money::plus)

    fun confirm() {
        check(status == OrderStatus.PAYMENT_AUTHORIZED) { "Cannot confirm order in $status" }
        status = OrderStatus.CONFIRMED
        events += OrderDomainEvent.Confirmed(id, total())
    }

    fun pullEvents(): List<OrderDomainEvent> = events.toList().also { events.clear() }

    companion object {
        fun place(id: OrderId, customerId: CustomerId, lines: List<OrderLine>): Order {
            require(lines.isNotEmpty()) { "Order needs at least one line" }
            return Order(id, customerId, lines, OrderStatus.PENDING).also {
                it.events += OrderDomainEvent.Placed(id, customerId, it.total())
            }
        }
    }
}
```

Go aggregate (inventory-service, `internal/domain/`):

```go
var ErrInsufficientStock = errors.New("insufficient stock")

type StockItem struct {
	SKU       SKU
	OnHand    int
	Reserved  int
	version   int64
}

func (s *StockItem) Available() int { return s.OnHand - s.Reserved }

func (s *StockItem) Reserve(orderID OrderID, qty int) (Reservation, error) {
	if qty <= 0 {
		return Reservation{}, fmt.Errorf("quantity must be positive: %d", qty)
	}
	if s.Available() < qty {
		return Reservation{}, ErrInsufficientStock
	}
	s.Reserved += qty
	return Reservation{OrderID: orderID, SKU: s.SKU, Quantity: qty}, nil
}
```

Anti-corruption layer (payment-service adapter):

```kotlin
class ProviderPaymentGateway(private val api: ProviderApi) : PaymentGateway {
    override fun authorize(request: Authorization): AuthorizationResult =
        when (val r = api.createCharge(request.toProviderCharge())) {
            is ProviderResponse.Approved -> AuthorizationResult.Authorized(PaymentReference(r.chargeId))
            is ProviderResponse.Declined -> AuthorizationResult.Declined(mapReason(r.code))
        }
}
```

## Recommended project structure

```text
services/order-service/src/main/kotlin/com/commerceflow/ordering/
  domain/model/        Order, OrderLine, Money, OrderStatus
  domain/event/        OrderDomainEvent (sealed)
  domain/port/         OrderRepository
  application/         PlaceOrder, ConfirmOrder use cases
  adapters/out/messaging/OrderEventMapper.kt   domain event -> contract (Avro)
```

## Best practices

- Name methods after business operations; no public setters on aggregates.
- Reference other aggregates and contexts by ID only.
- Validate in value object constructors so invalid states cannot exist.
- One aggregate per transaction; coordinate others with events.
- Keep a glossary per context; reuse the exact terms in code, events and UI.

## Anti-patterns

- **Anemic model**: data classes plus "service" classes holding all rules.
- **Reusing contract classes as entities** — couples your model to every consumer.
- **Huge aggregates** (Order containing Customer, Product and Shipment objects).
- **Primitive obsession**: `Long` for money, `String` for SKU everywhere.
- **Cross-context entities**: inventory importing product-service's `Product`.

## Failure scenarios

| Scenario | Handling |
|---|---|
| Concurrent updates to one aggregate | Optimistic locking (`version`) + retry (`transaction-management`). |
| Invariant violated by input | Value object/aggregate throws a domain error; API maps to 422. |
| Upstream event shape unexpected | ACL mapper rejects to DLT, model stays consistent (`retry-and-dead-letter-queue`). |
| Rule spans two services | Model as saga with compensation, not as a cross-service transaction. |

## Testing strategy

- Pure unit tests for aggregates and value objects: no Spring, no DB, fast.
- Test each invariant with an allowed and a rejected case.
- Test that operations record the expected domain events.
- Mapper tests: domain event → contract record round-trips against the `.avsc`.

## Definition of Done

- Every rule lives in exactly one aggregate or domain service.
- Aggregates expose intention-revealing methods and record domain events.
- Value objects validate themselves.
- Domain package has no framework imports and no contract classes.
- Unit tests cover each invariant and event.
