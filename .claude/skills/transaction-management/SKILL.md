---
name: transaction-management
description: Choose transaction boundaries and isolation in CommerceFlow services - PostgreSQL isolation levels and anomalies, optimistic locking, SELECT FOR UPDATE / SKIP LOCKED, atomic conditional updates, serialization-failure retries, Spring @Transactional pitfalls and pgx transactions in Go. Use when writing any code that modifies data or must stay consistent under concurrency.
---

# Transaction management

## Purpose

Keep each service's data consistent under concurrent requests and redelivered messages,
while keeping transactions short and local. Cross-service consistency is handled by sagas,
never by transactions.

## When to use

- Implementing a use case that writes data.
- Concurrency bugs: lost updates, double reservations, deadlocks.
- Adding outbox/inbox writes (they must share the business transaction).

## Prerequisites

- `postgresql-design`, `transactional-outbox`, `idempotent-consumer`.

## Concepts and architecture

**One use case = one local transaction** containing: aggregate change + outbox rows
(+ inbox row for consumers). No HTTP calls, no Kafka sends, no sleeps inside it.

**PostgreSQL isolation levels**

| Level | Prevents | Still possible | Use in CommerceFlow |
|---|---|---|---|
| Read Committed (default) | dirty reads | non-repeatable reads, lost updates without locking | default + optimistic locking or conditional updates |
| Repeatable Read | non-repeatable reads, phantoms (PG snapshot) | write skew | reports needing a stable snapshot |
| Serializable | all anomalies | — (aborts with `40001`) | rare multi-row invariants; must retry |

**Concurrency tools**

- **Optimistic locking:** `version` column; `UPDATE ... WHERE id = ? AND version = ?`;
  0 rows → conflict → retry or 409.
- **Atomic conditional update:** let the database check the invariant in one statement.
- **Pessimistic lock:** `SELECT ... FOR UPDATE` for short critical sections.
- **Work queues:** `FOR UPDATE SKIP LOCKED` for schedulers (saga timeouts, outbox cleanup).

**Retryable SQLSTATEs:** `40001` (serialization_failure), `40P01` (deadlock_detected).
Retry the *whole* transaction, with jitter, a few times.

## Step-by-step workflow

1. Identify the invariant and the rows it involves.
2. Choose the mechanism: conditional update → optimistic lock → `FOR UPDATE` →
   Serializable (in that order of preference).
3. Put the boundary on the application use case (not the controller or repository).
4. Include outbox/inbox writes in the same transaction.
5. Add retry for `40001`/`40P01` and optimistic conflicts where safe.
6. Test with real concurrency against PostgreSQL.

## Practical code examples

Inventory reservation as an atomic conditional update (Go, pgx):

```go
func (r *StockRepository) Reserve(ctx context.Context, tx pgx.Tx, sku domain.SKU, qty int) error {
	tag, err := tx.Exec(ctx, `
		UPDATE stock_item
		SET reserved = reserved + $1, version = version + 1
		WHERE sku = $2 AND on_hand - reserved >= $1`, qty, sku)
	if err != nil {
		return fmt.Errorf("reserve %s: %w", sku, err)
	}
	if tag.RowsAffected() == 0 {
		return domain.ErrInsufficientStock
	}
	return nil
}
```

Transaction helper with retry (Go):

```go
func InTx(ctx context.Context, pool *pgxpool.Pool, fn func(pgx.Tx) error) error {
	const attempts = 3
	for i := 0; ; i++ {
		err := pgx.BeginFunc(ctx, pool, fn)
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && (pgErr.Code == "40001" || pgErr.Code == "40P01") && i < attempts-1 {
			time.Sleep(time.Duration(rand.IntN(50*(i+1))) * time.Millisecond)
			continue
		}
		return err
	}
}

// use case: inbox + reservation + outbox in one transaction
err := InTx(ctx, pool, func(tx pgx.Tx) error {
	if dup, err := inbox.Record(ctx, tx, msg.ID, "inventory-service"); err != nil || dup {
		return err
	}
	if err := stock.Reserve(ctx, tx, cmd.SKU, cmd.Qty); err != nil {
		if errors.Is(err, domain.ErrInsufficientStock) {
			return outbox.Add(ctx, tx, events.ReservationFailed(cmd))
		}
		return err
	}
	return outbox.Add(ctx, tx, events.Reserved(cmd))
})
```

Optimistic locking (Kotlin, JPA):

```kotlin
@Entity @Table(name = "customer_order")
class OrderEntity(
    @Id val id: UUID,
    var status: String,
    @Version var version: Long = 0,
)
```

```kotlin
@Service
class ConfirmOrderService(private val orders: OrderRepository, private val events: OrderEvents) {
    @Retryable(retryFor = [OptimisticLockingFailureException::class], maxAttempts = 3, backoff = Backoff(delay = 20, random = true))
    @Transactional
    fun confirm(id: OrderId) {
        val order = orders.findById(id) ?: throw NotFound()
        order.confirm()
        orders.save(order)
        events.record(order.pullEvents())
    }
}
```

(`@Retryable` needs `spring-retry` + `@EnableRetry`; it must wrap *outside* the
transaction — put `@Retryable` on a separate bean that calls the `@Transactional` one, or
order the advice so retry is outermost.)

Scheduler claiming work without contention:

```sql
SELECT id FROM saga_instance
WHERE status = 'WAITING' AND deadline_at < now()
ORDER BY deadline_at
LIMIT 100
FOR UPDATE SKIP LOCKED;
```

## Recommended project structure

```text
Kotlin  application/ use cases annotated @Transactional; adapters/out/persistence repositories (no tx annotations)
Go      internal/adapters/postgres/tx.go (InTx helper); repositories accept pgx.Tx
```

## Best practices

- Transaction boundary in the application layer; repositories never start transactions.
- Keep transactions under ~100 ms; load before, compute, write, commit.
- Access rows in a consistent order (e.g. sorted SKUs) to avoid deadlocks.
- Read-only transactions: `@Transactional(readOnly = true)` / `pgx.TxOptions{AccessMode: pgx.ReadOnly}`.
- Treat a retried transaction as a fresh attempt: rebuild state inside the closure.

## Anti-patterns

- HTTP or Kafka calls inside a transaction.
- `@Transactional` on private methods or calling it via `this.` (proxy bypassed).
- Catching exceptions inside a transaction and continuing as if nothing happened (PG
  aborts the transaction on errors).
- Read-modify-write without a version or lock.
- Long-running transactions holding locks while waiting for users or networks.

## Failure scenarios

| Scenario | Symptom | Handling |
|---|---|---|
| Lost update | Two confirmations overwrite each other | Optimistic locking → retry/409. |
| Oversell | Reserved > on hand | Conditional update + `CHECK (reserved <= on_hand)`. |
| Deadlock | `40P01` | Consistent lock order; retry. |
| Crash after commit, before ack | Message redelivered | Inbox makes it a no-op. |

## Testing strategy

- Concurrency test: N goroutines/threads reserve the last unit; exactly one succeeds
  (Testcontainers PostgreSQL).
- Optimistic conflict test: two transactions update the same version; one fails.
- Retry test: inject a serialization failure (Serializable + conflicting tx) and assert a
  successful retry.

## Definition of Done

- Each use case runs in one local transaction including outbox/inbox writes.
- Invariants under concurrency enforced by conditional updates, versions or locks.
- Retries limited and only for retryable errors.
- Concurrency tests pass against real PostgreSQL.
