# 0007. Debezium CDC relays outbox rows to Kafka

- Status: Proposed
- Date: 2026-11-12
- Supersedes: [0002](0002-event-integration-outbox-cdc.md) (relay part)
- Deciders: project owner, event-driven-engineer, database-engineer
- Affected areas: `infrastructure/debezium`, `infrastructure/postgres`, `infrastructure/kafka`

## Context

Outbox rows (ADR-0006) must reach Kafka in commit order, without each service writing and
operating its own relay.

## Decision

- One Debezium PostgreSQL connector per service database, running in Kafka Connect, reads
  the WAL through logical replication (`pgoutput`, one publication on `outbox` only, one
  replication slot).
- The Outbox Event Router SMT routes each row to the topic in its `topic` column, uses
  `aggregate_id` as the Kafka key and maps `id`, `type` and `trace_parent` to headers.
- Payload bytes are passed through unchanged (byte-array converter), so Kafka carries
  exactly the Avro produced by the service.
- Connector configuration is declarative in `infrastructure/debezium/<short>-outbox.json`.

## Alternatives considered

- **Polling publisher in each service** — no Kafka Connect, but per-service relay code in
  two languages, polling load, and ordering/locking logic to get right.
- **Capturing business tables directly** — no outbox needed, but leaks internal schemas to
  consumers and couples them to every column change.

## Consequences

- Kafka Connect and Debezium become critical platform components.
- PostgreSQL must run with `wal_level=logical`; replication slots retain WAL while a
  connector is down — slot lag must be monitored and capped (`max_slot_wal_keep_size`).
- Connector restarts can republish rows; consumers are idempotent (ADR-0006).
- Database failover requires slot handling (`debezium-design.md`).
