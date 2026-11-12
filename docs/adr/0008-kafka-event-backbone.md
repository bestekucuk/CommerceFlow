# 0008. Apache Kafka as the event backbone

- Status: Proposed
- Date: 2026-11-12
- Deciders: project owner, commerce-architect, event-driven-engineer
- Affected areas: `infrastructure/kafka`, `contracts/events`, all services

## Context

Services integrate asynchronously (ADR-0006). The broker must keep events for replay,
preserve order per aggregate, let several services consume the same events independently,
and integrate with Debezium.

## Decision

- Apache Kafka (KRaft mode) is the only event broker.
- Schema Registry (Confluent-compatible) stores Avro schemas; subjects use
  `TopicRecordNameStrategy` and `BACKWARD` compatibility.
- Topics per aggregate family and kind: `cf.<aggregate>.events.v<major>` and
  `cf.<aggregate>.commands.v<major>`; dead-letter topics `<topic>.<consumer>.dlt`
  (`kafka-topic-strategy.md`).
- One consumer group per consuming service.
- Topics are created explicitly from `infrastructure/kafka/`; automatic topic creation is
  disabled.

## Alternatives considered

- **RabbitMQ** — strong routing and per-message acknowledgement; no long retention/replay
  model, no native Debezium sink path, ordering per key needs extra design.
- **Cloud-native queues/streams (SQS/SNS, Pub/Sub, Kinesis)** — managed, but ties the
  design to a provider before CF-004 is decided and has weaker local parity.
- **PostgreSQL LISTEN/NOTIFY or polling** — no extra infrastructure; does not scale to many
  consumers and offers no retention.

## Consequences

- Operating Kafka, Connect and Schema Registry (or buying a managed offering) is required.
- Ordering is guaranteed per key only; consumers must not assume global order.
- Retention enables replay and new projections, so consumers must stay idempotent.
