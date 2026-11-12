---
name: schema-evolution
description: Add, evolve or deprecate CommerceFlow event and command schemas in contracts/events - Avro rules, BACKWARD compatibility, subject naming, Schema Registry compatibility checks, optional fields with defaults, major-version topics, dual publishing and rollout order across independently deployed producers and consumers. Use whenever an .avsc file or the event catalog changes.
---

# Schema evolution

## Purpose

Change event contracts without breaking services that deploy at different times. Shared
contracts live in `contracts/events/`; each service generates its own code from them and
keeps its own domain model.

## When to use

- Adding a new event or command.
- Adding, removing, renaming or retyping a field.
- Deprecating an event or moving to a new major version.

## Prerequisites

- `contracts/events/README.md` (naming, envelope, money format).
- `docs/event-catalog/README.md` (producers and consumers).
- Owner: `event-driven-engineer`; cross-service rollout planned with the
  `commerce-architect` (`/cross-service-change`).

## Concepts and architecture

**Compatibility mode BACKWARD** (every subject): a consumer using the *new* schema can
read data written with the *previous* schema. Consequence: **upgrade consumers first**,
then producers.

| Change | BACKWARD compatible? | How |
|---|---|---|
| Add field with default | Yes | `{"name":"channel","type":["null","string"],"default":null}` |
| Remove field that had a default | Yes | Consumers stop reading it first |
| Add field without default | **No** | Give it a default |
| Rename field | **No** (unless alias) | Prefer new field + deprecate old; `aliases` only for reader-side rename |
| Change type (int → string) | **No** | New major version |
| Add enum symbol | Only with enum `default` | Always declare `"default"` on enums |

**Subjects:** `TopicRecordNameStrategy` → subject = `<topic>-<record full name>`, e.g.
`cf.order.events.v1-com.commerceflow.events.order.OrderPlaced`. Several event types share
one topic.

**Major versions:** breaking change → new file `OrderPlaced.v2.avsc`, namespace stays,
record name keeps, new topic `cf.order.events.v2`. Producer dual-publishes v1 and v2 until
all consumers moved.

## Step-by-step workflow

1. Classify the change with the table above.
2. Edit/add the `.avsc` under `contracts/events/<aggregate>/`.
3. Update `docs/event-catalog/README.md` (version, producer, consumers).
4. Validate syntax and compatibility locally (commands below).
5. Plan the rollout:
   - Additive: consumers that need the field deploy first; producer last.
   - Breaking: v2 topic + dual publish → migrate consumers one by one → stop v1.
6. Register schemas through CI before the producer deploy (`auto.register.schemas=false`
   in services).
7. Independent review by `code-reviewer`.

## Practical code examples

`contracts/events/common/EventMetadata.v1.avsc`:

```json
{
  "type": "record",
  "name": "EventMetadata",
  "namespace": "com.commerceflow.events.common",
  "fields": [
    { "name": "eventId", "type": { "type": "string", "logicalType": "uuid" } },
    { "name": "eventType", "type": "string" },
    { "name": "aggregateId", "type": "string" },
    { "name": "occurredAt", "type": { "type": "long", "logicalType": "timestamp-millis" } },
    { "name": "correlationId", "type": "string" },
    { "name": "causationId", "type": ["null", "string"], "default": null },
    { "name": "producer", "type": "string" }
  ]
}
```

`contracts/events/order/OrderPlaced.v1.avsc` (after an additive change adding `channel`):

```json
{
  "type": "record",
  "name": "OrderPlaced",
  "namespace": "com.commerceflow.events.order",
  "fields": [
    { "name": "metadata", "type": "com.commerceflow.events.common.EventMetadata" },
    { "name": "orderId", "type": "string" },
    { "name": "customerId", "type": "string" },
    { "name": "total", "type": {
        "type": "record", "name": "Money", "namespace": "com.commerceflow.events.common",
        "fields": [ { "name": "amountMinor", "type": "long" }, { "name": "currency", "type": "string" } ] } },
    { "name": "lineCount", "type": "int" },
    { "name": "channel", "type": ["null", { "type": "enum", "name": "SalesChannel", "symbols": ["WEB", "ADMIN", "UNKNOWN"], "default": "UNKNOWN" }], "default": null }
  ]
}
```

Compatibility check against Schema Registry (local stack on port 8090):

```bash
SUBJECT="cf.order.events.v1-com.commerceflow.events.order.OrderPlaced"
jq -n --rawfile s contracts/events/order/OrderPlaced.v1.avsc '{schema: $s, schemaType: "AVRO"}' \
  > /tmp/req.json
curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data @/tmp/req.json \
  "http://localhost:8090/compatibility/subjects/$SUBJECT/versions/latest"
# => {"is_compatible":true}
```

Note: references (`EventMetadata`, `Money`) must be registered and passed as `references`
in the request, or the tooling must inline them. The CI job uses one approach
consistently (CF-003 decides the tool).

Set compatibility per subject:

```bash
curl -s -X PUT -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data '{"compatibility":"BACKWARD"}' "http://localhost:8090/config/$SUBJECT"
```

Tolerant consumer (Kotlin, generated SpecificRecord):

```kotlin
val channel = event.channel?.name ?: "UNKNOWN"     // older producers send null
```

## Recommended project structure

```text
contracts/events/
  common/EventMetadata.v1.avsc, Money (inline or separate)
  order/OrderPlaced.v1.avsc, OrderConfirmed.v1.avsc, ...
  inventory/ReserveInventory.v1.avsc (command), InventoryReserved.v1.avsc, ...
docs/event-catalog/README.md
tests/contract/   compatibility check job
```

## Best practices

- Every new field is optional with a default; every enum has a `default` symbol.
- Never reuse a removed field name with a different meaning.
- Keep events small and stable; add fields rather than restructuring.
- Consumers ignore unknown fields and handle nulls for optional ones.
- Contract shape ≠ domain model: map in adapters, never share generated classes as domain
  objects.

## Anti-patterns

- Editing a schema and producer in one deploy without checking consumers.
- `auto.register.schemas=true` in production producers.
- A "common-events" runtime library shared by all services.
- Breaking change on the same topic with `NONE` compatibility "just this once".
- Putting another context's full state in an event.

## Failure scenarios

| Scenario | Effect | Handling |
|---|---|---|
| Producer deploys incompatible schema | Serialization fails (registry rejects) | Good — fix schema; CI should have caught it. |
| Consumer on old schema gets new field | Ignored (Avro resolution) | Expected. |
| Consumer cannot deserialize | ErrorHandlingDeserializer → DLT | Fix consumer, replay from DLT. |
| v1 retired too early | Lagging consumer misses events | Check consumer group lag on v1 is zero before stopping dual publish. |

## Testing strategy

- Avro parse of every `.avsc` in CI.
- Registry compatibility check for every changed subject (`tests/contract`).
- Consumer tests deserialize payloads written with the previous schema version.
- Producer mapper test: domain event → record validates against the schema.

## Definition of Done

- Change classified; schema valid; BACKWARD compatible or versioned as v<N+1>.
- Event catalog updated in the same change.
- Rollout order documented (and planned with the architect when multiple services change).
- Compatibility check and consumer tolerance tests pass.
