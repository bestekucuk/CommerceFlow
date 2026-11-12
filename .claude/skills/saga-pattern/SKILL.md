---
name: saga-pattern
description: Design and implement CommerceFlow sagas - the order saga orchestrated by order-service with Kafka commands and replies, persisted saga state, timeouts, compensations, correlation IDs, semantic locks and idempotent participants. Use when adding or changing a multi-service business workflow or a saga participant.
---

# Saga pattern

## Purpose

Keep a business process consistent across services without distributed transactions:
each step is a local transaction; failures are undone by compensating steps.

## When to use

- Changing the order saga (`docs/architecture/overview.md`).
- Adding a participant (e.g. fraud check) or a new long-running workflow.
- Investigating stuck or inconsistent orders.

## Prerequisites

- `transactional-outbox`, `idempotent-consumer`, `kafka-event-driven`,
  `transaction-management`.
- Design owned by `commerce-architect` + `event-driven-engineer`.

## Concepts and architecture

**Orchestration** (CommerceFlow default): `order-service` owns a saga state machine,
sends commands (`cf.<target>.commands.v1`) and reacts to replies/events.

```text
PENDING --ReserveInventory--> (InventoryReserved) INVENTORY_RESERVED
        --AuthorizePayment--> (PaymentAuthorized) PAYMENT_AUTHORIZED --> CONFIRMED (pivot)
failures:
  InventoryReservationFailed               --> REJECTED
  PaymentFailed / payment timeout          --> ReleaseInventory --> REJECTED
  inventory timeout                        --> ReleaseInventory (safe if nothing reserved) --> REJECTED
```

| Concept | Meaning here |
|---|---|
| Local transaction | Each state change + outbox command in one order_db tx. |
| Compensation | Semantic undo: `ReleaseInventory`, `VoidPayment`. Must be idempotent and always succeed eventually. |
| Pivot | Confirmation: after it, no compensation; later cancellation is a new business flow (`OrderCancelled`). |
| Semantic lock | Order status `PENDING`/`*_RESERVED` blocks conflicting actions (e.g. editing lines). |
| Correlation | `metadata.correlationId = sagaId = orderId`; `causationId` = triggering eventId. |
| Timeout | Every waiting state has `deadline_at`; a scheduler fires the timeout transition. |

## Step-by-step workflow

1. Draw the state machine: states, commands, replies, timeouts, compensations.
2. Define commands/replies in `contracts/events/` (`schema-evolution`).
3. Persist saga state in order_db (`saga_instance`).
4. Implement transitions as one use case each: load saga → check expected state → apply →
   write commands via outbox → commit.
5. Make participants idempotent (inbox) and their compensations idempotent and tolerant of
   "nothing to compensate".
6. Implement the timeout scheduler (`FOR UPDATE SKIP LOCKED`).
7. Test happy path, each failure and each timeout, plus duplicates and reordering.

## Practical code examples

Saga state table (order_db):

```sql
CREATE TABLE saga_instance (
  saga_id      uuid PRIMARY KEY,          -- = order id
  saga_type    text NOT NULL,             -- 'PlaceOrder'
  state        text NOT NULL,
  deadline_at  timestamptz,
  attempt      int  NOT NULL DEFAULT 0,
  version      bigint NOT NULL DEFAULT 0,
  updated_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX saga_instance_deadline_idx ON saga_instance (deadline_at) WHERE deadline_at IS NOT NULL;
```

Kotlin state machine (application layer):

```kotlin
enum class SagaState { AWAITING_INVENTORY, AWAITING_PAYMENT, COMPENSATING_INVENTORY, COMPLETED, REJECTED }

sealed interface SagaInput {
    val orderId: OrderId
    data class InventoryReserved(override val orderId: OrderId) : SagaInput
    data class InventoryFailed(override val orderId: OrderId, val reason: String) : SagaInput
    data class PaymentAuthorized(override val orderId: OrderId, val paymentId: String) : SagaInput
    data class PaymentFailed(override val orderId: OrderId, val reason: String) : SagaInput
    data class InventoryReleased(override val orderId: OrderId) : SagaInput
    data class Timeout(override val orderId: OrderId) : SagaInput
}

class PlaceOrderSaga(
    private val sagas: SagaRepository,
    private val orders: OrderRepository,
    private val commands: SagaCommands,     // outbox
    private val clock: Clock,
) {
    @Transactional
    fun on(input: SagaInput) {
        val saga = sagas.lock(input.orderId) ?: return          // unknown saga: ignore (idempotent)
        val order = orders.findById(input.orderId)!!
        when {
            saga.state == SagaState.AWAITING_INVENTORY && input is SagaInput.InventoryReserved -> {
                order.markInventoryReserved()
                commands.authorizePayment(order)
                saga.await(SagaState.AWAITING_PAYMENT, clock.instant().plusSeconds(60))
            }
            saga.state == SagaState.AWAITING_INVENTORY && input is SagaInput.InventoryFailed -> {
                order.reject(input.reason)
                saga.finish(SagaState.REJECTED)
            }
            // ... remaining transitions (see table below)
            else -> return                                       // stale or duplicate input: no-op
        }
        orders.save(order); sagas.save(saga)
    }
}
```

Prefer an explicit transition table over nested `when` once it grows:

```kotlin
val transitions: Map<Pair<SagaState, KClass<out SagaInput>>, (Ctx) -> Unit> = mapOf(
    (SagaState.AWAITING_INVENTORY to SagaInput.InventoryReserved::class) to { it.requestPayment() },
    (SagaState.AWAITING_INVENTORY to SagaInput.InventoryFailed::class)   to { it.reject() },
    (SagaState.AWAITING_INVENTORY to SagaInput.Timeout::class)           to { it.releaseInventoryThenReject() },
    (SagaState.AWAITING_PAYMENT   to SagaInput.PaymentAuthorized::class) to { it.confirm() },
    (SagaState.AWAITING_PAYMENT   to SagaInput.PaymentFailed::class)     to { it.releaseInventoryThenReject() },
    (SagaState.AWAITING_PAYMENT   to SagaInput.Timeout::class)           to { it.voidPaymentReleaseInventoryThenReject() },
    (SagaState.COMPENSATING_INVENTORY to SagaInput.InventoryReleased::class) to { it.reject() },
)
```

Timeout scheduler:

```kotlin
@Scheduled(fixedDelay = 5_000)
fun fireTimeouts() {
    sagas.claimExpired(limit = 100)        // SELECT ... WHERE deadline_at < now() FOR UPDATE SKIP LOCKED
        .forEach { saga.on(SagaInput.Timeout(it.orderId)) }   // each in its own transaction
}
```

Idempotent compensation in inventory-service (Go):

```go
func (u *ReleaseInventory) Handle(ctx context.Context, tx pgx.Tx, cmd ReleaseCommand) error {
	if _, err := tx.Exec(ctx, `
		UPDATE stock_item s SET reserved = s.reserved - r.quantity
		FROM reservation r
		WHERE r.order_id = $1 AND r.status = 'ACTIVE' AND s.sku = r.sku`, cmd.OrderID); err != nil {
		return err
	}
	if _, err := tx.Exec(ctx, `UPDATE reservation SET status = 'RELEASED' WHERE order_id = $1 AND status = 'ACTIVE'`, cmd.OrderID); err != nil {
		return err
	}
	// Always reply, even when nothing was reserved (0 rows updated): the saga waits for the reply.
	return u.outbox.Add(ctx, tx, events.InventoryReleased(cmd))
}
```

## Recommended project structure

```text
services/order-service/.../application/saga/      PlaceOrderSaga, transitions, SagaRepository port
services/order-service/.../adapters/in/messaging/ reply listeners -> SagaInput
services/order-service/.../adapters/out/messaging/ SagaCommands (outbox)
services/<participant>/.../application/            command handlers + compensations
contracts/events/<aggregate>/                      commands and replies
tests/integration/, tests/resilience/              saga scenarios
```

## Best practices

- Saga state and aggregate state change in the same transaction as the outbox command.
- Treat every input as possibly duplicate, late or out of order: check the current state.
- Compensations are commands with replies, retried until they succeed.
- Put the pivot as late as possible (authorize payment before confirming, capture later).
- Expose saga state for support (admin view, runbook "saga stuck in PENDING").

## Anti-patterns

- Choreography spaghetti: many services reacting to each other without an owner.
- Synchronous HTTP calls between saga steps.
- Compensation that can fail permanently (e.g. refund needing manual input) without an
  escalation path.
- Missing timeouts — orders stuck forever.
- Participants calling back into order-service's database.

## Failure scenarios

| Scenario | Outcome |
|---|---|
| Duplicate `InventoryReserved` | Inbox drops it; or state check makes it a no-op. |
| `PaymentAuthorized` after payment timeout fired | State is `COMPENSATING_*`: void the late authorization (send `VoidPayment`). |
| Inventory down for 10 min | Timeout → release (no-op) → `REJECTED`; customer notified. |
| Order-service crash mid-transition | Tx rolled back; reply redelivered; transition replays. |
| Compensation keeps failing | Retries with backoff → DLT → alert → runbook. |

## Testing strategy

- Unit: transition table — every (state, input) pair, including unexpected ones (no-op).
- Integration (Testcontainers): saga + outbox + inbox in order-service.
- `tests/integration`: full happy path across services on Compose.
- `tests/resilience`: Toxiproxy outage of each participant → expected terminal state;
  duplicate delivery of each reply.

## Definition of Done

- State machine documented (overview updated) with timeouts and compensations.
- Every transition is one local transaction with outbox commands.
- Participants and compensations idempotent; late replies handled.
- Timeout scheduler in place; stuck-saga metric and alert exist.
- Happy, failure, timeout and duplicate tests pass.
