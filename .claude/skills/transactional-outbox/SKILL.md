---
name: transactional-outbox
description: Implement the transactional outbox in a CommerceFlow service - outbox table schema, writing aggregate changes and outbox rows atomically, event identity, topic routing, Avro payload serialization, trace context capture, ordering and cleanup - in Kotlin (Spring) and Go (pgx). Use whenever a service publishes an event or saga command.
---

# Transactional outbox

## Purpose

Publish events and saga commands exactly when the business change commits — never
without it, never before it — by writing them to an `outbox` table in the same database
transaction. Debezium then publishes them (`debezium-cdc`).

## When to use

- Any use case that emits a domain event or a saga command.
- Creating the baseline schema of a new service.

## Prerequisites

- `transaction-management`, `kafka-event-driven`, `schema-evolution`.
- ADR-0002 (outbox + Debezium).

## Concepts and architecture

**Atomicity:** `BEGIN; UPDATE aggregate; INSERT INTO outbox; COMMIT;` — either both exist or
neither. No dual write.

**Outbox schema (identical in every service):**

| Column | Type | Meaning |
|---|---|---|
| `id` | `uuid` PK | Event ID (`metadata.eventId`), Kafka header `id`, consumers' inbox key |
| `aggregate_type` | `text` | `order`, `stock_item`, ... (diagnostics) |
| `aggregate_id` | `text` | Kafka message key → per-aggregate ordering |
| `type` | `text` | `OrderCreated`, `ReserveInventory` → header `eventType` |
| `topic` | `text` | Destination, e.g. `cf.order.events.v1`; Debezium routes on it |
| `payload` | `bytea` | Avro, Confluent wire format (magic byte + schema id + body) |
| `occurred_at` | `timestamptz` | Event time |
| `trace_parent` | `text` | W3C `traceparent` of the producing span → header `traceparent` |

**Payload format:** services serialize with the registered Avro schema (Schema Registry
client, `auto.register.schemas=false`), so the bytes on Kafka match the reviewed contract.
Debezium passes bytes through unchanged (`debezium-cdc`). If this approach changes, record
it in an ADR.

**Cleanup:** either delete rows in the same transaction right after inserting (the WAL
still contains the insert, Debezium captures it, the router ignores the delete) or delete
captured rows with a periodic job. CommerceFlow default: **periodic job** (rows kept 24 h
for debugging).

## Step-by-step workflow

1. Add the outbox table in the service's first migration.
2. Define an output port (`OrderEvents` / `EventRecorder`) in the application layer.
3. Implement the port in `adapters/out/messaging` mapping domain event → contract record
   → outbox row.
4. Call it inside the use-case transaction after saving the aggregate.
5. Capture the current `traceparent` into the row.
6. Add the cleanup job.
7. Integration-test atomicity (rollback → no outbox row).

## Practical code examples

Migration (`V1__outbox_inbox.sql` / `000001_outbox_inbox.up.sql`):

```sql
CREATE TABLE outbox (
  id             uuid        PRIMARY KEY,
  aggregate_type text        NOT NULL,
  aggregate_id   text        NOT NULL,
  type           text        NOT NULL,
  topic          text        NOT NULL,
  payload        bytea       NOT NULL,
  occurred_at    timestamptz NOT NULL DEFAULT now(),
  trace_parent   text
);
CREATE INDEX outbox_occurred_at_idx ON outbox (occurred_at);
ALTER TABLE outbox SET (autovacuum_vacuum_scale_factor = 0.01);
```

Kotlin outbox adapter:

```kotlin
@Component
class OutboxOrderEvents(
    private val jdbc: JdbcClient,
    private val serializer: AvroSerializer,          // wraps KafkaAvroSerializer, auto.register.schemas=false
    private val mapper: OrderEventMapper,            // domain event -> Avro SpecificRecord
) : OrderEvents {

    override fun record(events: List<OrderDomainEvent>) {
        val traceParent = currentTraceParent()
        events.forEach { event ->
            val record = mapper.toContract(event)    // includes metadata.eventId
            jdbc.sql("""
                INSERT INTO outbox (id, aggregate_type, aggregate_id, type, topic, payload, occurred_at, trace_parent)
                VALUES (:id, 'order', :aggregateId, :type, :topic, :payload, :occurredAt, :traceParent)
            """.trimIndent())
                .param("id", record.metadata.eventId.let(UUID::fromString))
                .param("aggregateId", event.orderId.value.toString())
                .param("type", record.schema.name)
                .param("topic", mapper.topicFor(event))          // cf.order.events.v1 or cf.inventory.commands.v1
                .param("payload", serializer.serialize(mapper.topicFor(event), record))
                .param("occurredAt", Timestamp.from(event.occurredAt))
                .param("traceParent", traceParent)
                .update()
        }
    }
}

fun currentTraceParent(): String? {
    val carrier = mutableMapOf<String, String>()
    GlobalOpenTelemetry.getPropagators().textMapPropagator
        .inject(Context.current(), carrier) { c, k, v -> c!![k] = v }
    return carrier["traceparent"]
}
```

`JdbcClient` joins the surrounding `@Transactional` — the use case owns the boundary.

Go outbox writer (pgx):

```go
type Message struct {
	ID            uuid.UUID
	AggregateType string
	AggregateID   string
	Type          string
	Topic         string
	Payload       []byte // Avro, Confluent framed
	OccurredAt    time.Time
}

func (o *Outbox) Add(ctx context.Context, tx pgx.Tx, m Message) error {
	carrier := propagation.MapCarrier{}
	otel.GetTextMapPropagator().Inject(ctx, carrier)
	_, err := tx.Exec(ctx, `
		INSERT INTO outbox (id, aggregate_type, aggregate_id, type, topic, payload, occurred_at, trace_parent)
		VALUES ($1, $2, $3, $4, $5, $6, $7, NULLIF($8, ''))`,
		m.ID, m.AggregateType, m.AggregateID, m.Type, m.Topic, m.Payload, m.OccurredAt, carrier.Get("traceparent"))
	if err != nil {
		return fmt.Errorf("insert outbox %s: %w", m.Type, err)
	}
	return nil
}
```

Cleanup job (any language, every 10 minutes):

```sql
DELETE FROM outbox WHERE id IN (
  SELECT id FROM outbox WHERE occurred_at < now() - interval '24 hours' LIMIT 5000
);
```

Rows older than the Debezium lag are safe to delete; alert if replication lag exceeds the
retention window (`debezium-cdc`).

## Recommended project structure

```text
services/<svc>/.../application/            port: OrderEvents / EventRecorder
services/<svc>/.../adapters/out/messaging/ OutboxOrderEvents, OrderEventMapper, AvroSerializer
services/<svc>/.../db/migration/V1__outbox_inbox.sql
infrastructure/debezium/<svc>-outbox.json  connector (event-driven-engineer)
```

## Best practices

- Generate `eventId` once, in the mapper, and reuse it for the row ID.
- One outbox row per event; multiple events per transaction are fine and keep order by
  insertion within the same key.
- Map domain → contract in the adapter; the domain never sees Avro classes.
- Never update outbox rows; insert-only (plus cleanup deletes).
- Same schema in every service so one connector template fits all.

## Anti-patterns

- `kafkaTemplate.send()` inside or after `@Transactional` for domain events.
- Publishing from an `@TransactionalEventListener(AFTER_COMMIT)` — still a dual write.
- Polling the outbox from the application *and* running Debezium.
- Storing JSON that does not match the Avro contract.
- Outbox rows written in a different transaction than the aggregate change.

## Failure scenarios

| Scenario | Effect | Handling |
|---|---|---|
| Transaction rolls back | No row → no event | Correct by construction. |
| Debezium down | Rows accumulate, events delayed | Alert on slot lag; rows are kept until captured. |
| Schema not registered | Serialization fails, tx rolls back | Register via CI before deploying the producer. |
| Cleanup deletes uncaptured rows | Lost events | Retention ≫ max expected CDC lag; alert first. |

## Testing strategy

- Integration (Testcontainers PostgreSQL): use case commits → exactly one outbox row with
  correct topic/key/type; forced exception → zero rows.
- Mapper test: payload deserializes with the contract schema.
- End-to-end (`tests/integration`): row → Debezium → Kafka record with headers `id`,
  `eventType`, `traceparent`.

## Definition of Done

- Outbox table present with the standard schema.
- Every event/command is written via the outbox inside the business transaction.
- `eventId`, key, topic and trace context set correctly.
- Atomicity and mapping tests pass; cleanup job in place.
