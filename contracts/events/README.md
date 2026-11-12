# Event Contracts

Source of truth for every CommerceFlow Kafka message. No schemas exist yet; this file
defines the rules the first schemas must follow.

## Layout

```
contracts/events/
  <aggregate>/
    <EventName>.v<major>.avsc        e.g. order/OrderPlaced.v1.avsc
  common/
    EventMetadata.v1.avsc            shared envelope fields
```

## Format and registry

- Apache Avro, namespace `com.commerceflow.events.<aggregate>`.
- Registered in Confluent-compatible Schema Registry.
- Subject naming: `TopicRecordNameStrategy` (several event types share one topic per
  aggregate).
- Compatibility mode: `BACKWARD` for every subject.

## Topics

- Facts: `cf.<aggregate>.events.v<major>` (e.g. `cf.order.events.v1`)
- Saga commands: `cf.<aggregate>.commands.v<major>`
- Dead letters: `<topic>.<consumer>.dlt`
- Key: aggregate ID as string. Ordering is guaranteed per key only.

## Envelope

Every event record includes a `metadata` field of type `EventMetadata`:

| field | type | meaning |
|---|---|---|
| `eventId` | string (UUID) | unique ID; consumers' inbox key |
| `eventType` | string | e.g. `OrderPlaced` |
| `aggregateId` | string | matches the Kafka key |
| `occurredAt` | timestamp-millis | when the fact happened |
| `correlationId` | string | ties all messages of one saga/request together |
| `causationId` | string, nullable | `eventId` of the message that caused this one |
| `producer` | string | e.g. `order-service` |

Trace context travels in the Kafka `traceparent` header, not the payload.

## Content rules

- Facts are past tense (`OrderPlaced`); commands are imperative (`ReserveInventory`).
- Money is `{ amountMinor: long, currency: string(ISO 4217) }`. No floats.
- Reference other contexts' data by ID only; do not copy their state.
- Additive changes: new fields must be optional with defaults.
- Breaking changes: new major version file and topic; follow the
  `event-contract-change` skill (`.claude/skills/event-contract-change/`).

## Use by services

Services read schemas directly from this folder at build time and generate their own
code (Avro codegen in Gradle for Kotlin, `go generate` for Go). Generated code stays
inside each service; there is no shared compiled library. Exact tooling: CF-003.

Schemas are registered in Schema Registry at deploy time, not by application startup.
