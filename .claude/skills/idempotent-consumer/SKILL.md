---
name: idempotent-consumer
description: Make CommerceFlow Kafka consumers idempotent with the inbox pattern - inbox table keyed by eventId, recording and side effects in one transaction, natural idempotency, offset commit after commit, inbox retention - in Spring Kafka and Go. Use for every consumer of events or saga commands.
---

# Idempotent consumer (inbox pattern)

## Purpose

Kafka and Debezium deliver at least once. A consumer must produce the same result whether a
message arrives once or five times.

## When to use

- Writing any `@KafkaListener` or Go consumer.
- Investigating duplicate side effects (double emails, double reservations).

## Prerequisites

- `kafka-event-driven`, `transaction-management`, `transactional-outbox`.

## Concepts and architecture

**Inbox table** (per consuming service, in its own DB):

| Column | Type | Notes |
|---|---|---|
| `message_id` | `uuid` | `id` header = `metadata.eventId` |
| `consumer` | `text` | handler name, allows several handlers per service |
| `received_at` | `timestamptz` | for retention |
| PK | `(message_id, consumer)` | |

**Algorithm (one DB transaction):**

```text
BEGIN
  INSERT INTO inbox (message_id, consumer) VALUES (...) ON CONFLICT DO NOTHING
  if 0 rows inserted -> COMMIT, ack (duplicate)
  apply side effects (domain change, outbox rows)
COMMIT
commit Kafka offset
```

If the process dies after `COMMIT` but before the offset commit, the redelivered message
hits the inbox and is skipped.

**Side effects outside the DB** (notification-service sends email): record intent in the
DB in the same tx (`notification` row with unique `(event_id, channel)`), send afterwards
from a worker that marks it sent — the provider call itself should carry an idempotency
key if supported.

**Natural idempotency** (complements the inbox): "set status = CONFIRMED where status =
PAYMENT_AUTHORIZED" is idempotent by itself.

## Step-by-step workflow

1. Add the inbox table in the service migration.
2. Extract `eventId` from the `id` header (fall back to `metadata.eventId`).
3. Wrap inbox insert + handler in one transaction.
4. Use manual offset commit after the transaction (`kafka-event-driven`).
5. Add retention cleanup (keep ≥ topic retention, e.g. 30 days).
6. Test duplicate and crash-before-ack scenarios.

## Practical code examples

Migration:

```sql
CREATE TABLE inbox (
  message_id  uuid        NOT NULL,
  consumer    text        NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, consumer)
);
CREATE INDEX inbox_received_at_idx ON inbox (received_at);
```

Kotlin:

```kotlin
@Component
class Inbox(private val jdbc: JdbcClient) {
    /** @return true if the message is new and must be processed */
    fun firstSeen(messageId: UUID, consumer: String): Boolean =
        jdbc.sql("INSERT INTO inbox (message_id, consumer) VALUES (:id, :c) ON CONFLICT DO NOTHING")
            .param("id", messageId).param("c", consumer)
            .update() == 1
}

@Service
class HandleInventoryReply(private val inbox: Inbox, private val saga: PlaceOrderSaga) {
    @Transactional
    operator fun invoke(event: SpecificRecord, eventId: String) {
        if (!inbox.firstSeen(UUID.fromString(eventId), "order-saga")) return
        saga.on(event.toSagaInput())       // joins this transaction (writes saga state + outbox)
    }
}
```

Go:

```go
// Record returns duplicate=true when the message was already processed.
func (i *Inbox) Record(ctx context.Context, tx pgx.Tx, id uuid.UUID, consumer string) (duplicate bool, err error) {
	tag, err := tx.Exec(ctx,
		`INSERT INTO inbox (message_id, consumer) VALUES ($1, $2) ON CONFLICT DO NOTHING`, id, consumer)
	if err != nil {
		return false, fmt.Errorf("inbox insert: %w", err)
	}
	return tag.RowsAffected() == 0, nil
}

func (c *CommandConsumer) handle(ctx context.Context, r *kgo.Record) error {
	id, err := uuid.Parse(header(r, "id"))
	if err != nil {
		return c.dlt.Send(ctx, r, fmt.Errorf("missing or invalid id header: %w", err)) // permanent
	}
	return postgres.InTx(ctx, c.pool, func(tx pgx.Tx) error {
		dup, err := c.inbox.Record(ctx, tx, id, "inventory-commands")
		if err != nil || dup {
			return err
		}
		return c.dispatch(ctx, tx, r)       // reserve/release + outbox reply
	})
}
```

Retention (daily):

```sql
DELETE FROM inbox WHERE received_at < now() - interval '30 days';
```

## Recommended project structure

```text
services/<svc>/.../adapters/in/messaging/   listeners: header extraction, call use case
services/<svc>/.../adapters/out/persistence/Inbox (Kotlin) | internal/adapters/postgres/inbox.go (Go)
services/<svc>/.../db/migration/V1__outbox_inbox.sql
```

## Best practices

- Dedupe on `eventId`, never on payload hashes or offsets (offsets change on replays).
- Inbox and side effects share the transaction; nothing in between.
- Keep inbox retention ≥ topic retention + max replay window.
- Use the consumer name in the key when a service has several independent handlers.
- Log duplicates at debug level with `eventId` — they are normal.

## Anti-patterns

- In-memory dedupe caches (lost on restart, not shared across replicas).
- Checking the inbox in one transaction and processing in another.
- Committing offsets before processing ("at-most-once").
- External calls (email, payment provider) inside the DB transaction.

## Failure scenarios

| Scenario | Outcome |
|---|---|
| Same event delivered twice | Second insert conflicts → skipped. |
| Crash after DB commit, before offset commit | Redelivered → skipped. |
| Crash before DB commit | Nothing persisted → reprocessed cleanly. |
| Replay of a topic from earliest | Old events skipped while inbox retention covers them; older ones must be naturally idempotent or replay window limited. |
| Missing `id` header | Permanent error → DLT. |

## Testing strategy

- Integration (Testcontainers PostgreSQL + Kafka): send the same record twice → one side
  effect, one outbox row.
- Crash simulation: process, throw after commit before ack (test hook) → redelivery → no
  second effect.
- Concurrency: two consumers (rebalance) process the same message concurrently → PK
  conflict makes one a no-op.

## Definition of Done

- Inbox table and retention in place.
- Every handler records the inbox entry in the same transaction as its effects.
- Offsets committed after the transaction.
- Duplicate and crash tests pass.
