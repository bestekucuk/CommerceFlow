# 0006. Transactional outbox for publishing events and commands

- Status: Proposed
- Date: 2026-11-12
- Supersedes: [0002](0002-event-integration-outbox-cdc.md) (outbox and inbox part)
- Deciders: project owner, commerce-architect, event-driven-engineer
- Affected areas: `services/*`, `contracts/events`

## Context

A service that changes its state must publish an event about it. Writing to PostgreSQL
and Kafka in two steps (dual write) loses the event if the process stops between them, or
publishes an event for a change that was rolled back. Saga commands have the same need.

## Decision

- Every service that publishes has an `outbox` table with a fixed schema (`id`,
  `aggregate_type`, `aggregate_id`, `type`, `topic`, `payload`, `occurred_at`,
  `trace_parent`), defined in `docs/event-catalog/outbox-design.md`.
- The use case writes the aggregate change and its outbox rows in **one local
  transaction**. Application code never sends domain events or commands to Kafka directly.
- `payload` holds the event serialized with the registered Avro schema.
- Consumers record each message in an `inbox` table (`message_id`, `consumer`) in the same
  transaction as their side effects and skip duplicates.
- Outbox rows are relayed to Kafka by CDC (ADR-0007).

## Alternatives considered

- **Direct publish after commit** — simplest; loses events on crashes.
- **Kafka transactions spanning DB and broker** — not possible across PostgreSQL and Kafka
  without XA; not supported by our stack.
- **Event sourcing** — events as the source of truth; powerful but a large shift in
  modelling and tooling for every service.

## Consequences

- Delivery is at-least-once; every consumer must be idempotent (inbox).
- Outbox tables need cleanup and monitoring (row age).
- Each service implements outbox and inbox itself, in its language; there is no shared
  library.
