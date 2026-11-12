---
name: outbox-inbox
description: How CommerceFlow services publish events with a transactional outbox plus Debezium CDC, and consume them idempotently with an inbox table. Use when implementing any producer or consumer.
---

# Transactional outbox and inbox

## Publishing (outbox)

Each service database has an `outbox` table:

| column | type | notes |
|---|---|---|
| `id` | uuid | event ID, becomes the `id` header and the consumers' dedupe key |
| `aggregate_type` | text | e.g. `order`; Debezium routes on this |
| `aggregate_id` | text | becomes the Kafka message key (ordering per aggregate) |
| `type` | text | event name, e.g. `OrderPlaced` |
| `payload` | jsonb or bytea | serialized event |
| `occurred_at` | timestamptz | |
| `trace_parent` | text | W3C traceparent, copied to a Kafka header |

Rules:
- The use case writes the aggregate change and the outbox row in **one transaction**.
- No application code calls the Kafka producer for domain events.
- Debezium's PostgreSQL connector with the Outbox Event Router SMT reads the WAL and
  publishes to the topic for `aggregate_type`. Connector configs live in
  `infrastructure/debezium/` (one per service); database and replication setup in
  `infrastructure/postgres/`.
- Outbox rows are deleted by a scheduled job after Debezium has captured them, or
  Debezium is configured to ignore deletes.

## Consuming (inbox)

Each consuming service has an `inbox` table: `message_id` (primary key), `consumer`,
`received_at`.

Rules:
- In one transaction: insert into `inbox`; if the key already exists, skip; otherwise
  apply side effects (which may write new outbox rows).
- Commit the Kafka offset only after the transaction commits (at-least-once delivery,
  effectively-once processing).
- Poison messages go to `<topic>.<consumer>.dlt` after bounded retries with backoff.
- Restore trace context from the `traceparent` header before processing.

Each service implements this itself, in its own language. There is no shared outbox
library across services.
