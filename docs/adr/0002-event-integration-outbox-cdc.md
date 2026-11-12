# 0002. Event integration via transactional outbox and Debezium CDC

- Status: Proposed
- Date: 2026-11-12
- Affected areas: `services/*`, `contracts/events`, `infrastructure/debezium`

## Context

Services must publish domain events reliably when their state changes. Writing to the
database and Kafka separately risks lost or phantom events (dual-write problem).

## Decision

- Services write events to an `outbox` table in the same transaction as the state change.
- Debezium (Kafka Connect, PostgreSQL connector, Outbox Event Router SMT) publishes outbox
  rows to Kafka.
- Consumers use an `inbox` table keyed by event ID to process each message once.
- Avro schemas registered in Schema Registry with BACKWARD compatibility.

## Alternatives considered

- Polling publisher inside each service — no Kafka Connect dependency, but adds latency
  and per-service publishing code.
- Direct Kafka publish after commit — loses events on crash between commit and publish.

## Consequences

- Kafka Connect and Debezium become critical platform components.
- PostgreSQL needs logical replication (`wal_level=logical`) and a replication slot per
  service; slot growth must be monitored.
- Event ordering is guaranteed per aggregate (message key), not globally.
