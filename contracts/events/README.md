# Event Contracts

Source of truth for every CommerceFlow Kafka message. Implemented schemas:
`common/EventMetadata.v1.avsc`, `product/ProductCreated.v1.avsc`; the rest of the
catalogue is planned (CF-002). Detailed event definitions, naming and
versioning: `docs/event-catalog/` (event-catalog.md, event-naming-conventions.md,
event-versioning-policy.md).

## Layout

```
contracts/events/
  <aggregate>/
    <EventName>.v<major>.avsc        e.g. order/OrderCreated.v1.avsc
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

Every event record has two fields: `metadata` of type `EventMetadata`
(`common/EventMetadata.v1.avsc`) and `payload`, a record with the event's own data.

| metadata field | type | meaning |
|---|---|---|
| `eventId` | string (UUID) | unique ID; equals the Kafka `id` header; consumers' inbox key |
| `eventType` | string | e.g. `ProductCreated` |
| `aggregateType` | string | e.g. `product` |
| `aggregateId` | string | matches the Kafka key |
| `occurredAt` | timestamp-millis | when the fact happened |
| `schemaVersion` | int | major version (matches `.v<N>` and the topic suffix) |
| `correlationId` | string | ties all messages of one saga/request together (from `X-Correlation-Id`) |
| `causationId` | string, nullable | `eventId` of the message that caused this one |
| `producer` | string | e.g. `product-service` |

## Compatibility policy

Subjects use **BACKWARD** compatibility (`TopicRecordNameStrategy`:
`<topic>-<namespace>.<Record>`). Additive changes (optional fields with defaults, enum
symbols with an enum default) keep the same file and topic; consumers that need a new field
deploy first. Any other change is a new major version (`<Event>.v<N+1>.avsc`, topic
`.v<N+1>`, dual publishing). Producers serialize with the latest registered version
(`auto.register.schemas=false`, `use.latest.version=true`); schemas are registered by
`infrastructure/scripts/register-schemas.ps1` (pipeline later), and
`register-schemas.ps1 -CheckOnly` checks compatibility. Full policy:
`docs/event-catalog/event-versioning-policy.md`.

Trace context travels in the Kafka `traceparent` header, not the payload.

## Content rules

- Facts are past tense (`OrderCreated`); commands are imperative (`ReserveInventory`).
- Money is `{ amountMinor: long, currency: string(ISO 4217) }`. No floats.
- Reference other contexts' data by ID only; do not copy their state.
- Additive changes: new fields must be optional with defaults.
- Breaking changes: new major version file and topic; follow the
  `schema-evolution` skill (`.claude/skills/schema-evolution/`).

## Use by services

There is no shared compiled library; each service handles contracts itself:

- **Kotlin** (product-service): the Gradle Avro plugin generates classes from this folder at
  build time (`-PcontractsDir=/contracts` in Docker builds). Generated code stays in
  `build/`.
- **Go** (inventory-service): no code generation. The consumer decodes with the writer
  schema fetched from Schema Registry by id (hamba/avro) into a struct mirroring the
  contract; tests build messages from the real `.avsc` files here.

CF-003 decides whether Go services should generate code as well.

Schemas are registered in Schema Registry at deploy time, not by application startup.
