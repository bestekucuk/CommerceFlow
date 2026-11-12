---
name: create-domain-event
description: Workflow to design a new or changed versioned CommerceFlow domain event or saga command - Avro schema in contracts/events with the shared metadata envelope, compatibility check, topic and key, event catalog update, producer outbox mapping and consumer inbox handling, with rollout order. Use when an event or command is added, evolved or deprecated.
argument-hint: "<EventName> <producer-service> <consumers...>"
---

# create-domain-event

## Purpose

Publish facts (and saga commands) as stable, versioned contracts that independently
deployed producers and consumers can rely on.

## Invocation

```text
/create-domain-event OrderShipped order-service notification-service storefront-read-model
```

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Event name | yes | past tense for facts (`OrderShipped`), imperative for commands (`ReserveInventory`) |
| Producer | yes | exactly one owning service |
| Consumers | no | discovered from requirements; each needs an inbox handler |
| Change type | no | new / additive / breaking — classified in step 3 |

## Required context

`contracts/events/README.md`, `docs/event-catalog/README.md`, existing schemas of the
aggregate, ADR-0002, the producer's and consumers' `CLAUDE.md`.

## Relevant agents

`event-driven-engineer` (schema, catalog, topics), `commerce-architect` (rollout plan when
several services change), producer/consumer language engineers, `code-reviewer`.

## Relevant skills

`schema-evolution`, `kafka-event-driven`, `transactional-outbox`, `idempotent-consumer`,
`domain-driven-design`, `saga-pattern` (for commands).

## Execution steps

1. **Model** the fact: which aggregate, what happened, key (aggregate ID), which data is
   needed by consumers (IDs over copied state).
2. **Schema**: `contracts/events/<aggregate>/<Event>.v1.avsc` with `metadata:
   EventMetadata`, money as `Money`, optional fields with defaults, enums with `default`.
3. **Classify** existing-event changes (additive vs breaking → `.v2` file and topic).
4. **Catalog**: add/update the row in `docs/event-catalog/README.md` (topic, producer,
   consumers).
5. **Topic**: ensure `cf.<aggregate>.events.v<N>` (or `.commands.`) exists in
   `infrastructure/kafka/` with key, partitions, retention; DLTs for each consumer.
6. **Rollout plan** (architect if > 1 service): consumers first for additive changes;
   dual publish for breaking.
7. **Producer step** (owning engineer): domain event → contract mapper → outbox row with
   correct `topic`, `aggregate_id`, `type`.
8. **Consumer steps** (each owning engineer): inbox-backed handler, retry/DLT policy,
   tolerant reading of optional fields.
9. **Review**: `code-review`.

## Validation steps

- Every `.avsc` parses; compatibility check against the latest registered version passes
  (`schema-evolution` commands) or is versioned as breaking.
- Stop hook A1 quiet (catalog updated with the contract).
- Producer mapper test validates the record against the schema.
- Consumer duplicate-delivery test passes (inbox).

## Expected output

Schema file(s), catalog diff, topic declaration, rollout order with owners, producer and
consumer changes with test results.

## Failure handling

| Situation | Action |
|---|---|
| Incompatible change detected | Switch to a v2 schema/topic; never relax compatibility. |
| Event would carry another context's state | Reduce to IDs; consumers keep their own projections. |
| No Schema Registry running | Parse-check only; mark compatibility as "not verified". |
| Consumer cannot be updated now | Additive change only; consumer tolerates missing field later. |
