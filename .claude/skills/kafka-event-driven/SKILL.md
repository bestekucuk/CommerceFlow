---
name: kafka-event-driven
description: Use Apache Kafka correctly in CommerceFlow - topic naming and configuration, aggregate partition keys, event identity, at-least-once delivery, consumer groups, offset commits after the database transaction, ordering, rebalances, consumer lag and Avro serialization with Schema Registry in Spring Kafka and Go (franz-go). Use when adding a topic, producer path or consumer.
---

# Kafka event-driven integration

## Purpose

Reliable asynchronous integration between CommerceFlow services: no lost events, safe
duplicates, ordering where it matters, and observable lag.

## When to use

- Defining a new topic or event flow.
- Writing or tuning a consumer.
- Investigating lag, duplicates, ordering issues or rebalances.

## Prerequisites

- `transactional-outbox` (how events reach Kafka), `idempotent-consumer`,
  `schema-evolution`, `retry-and-dead-letter-queue`.
- `contracts/events/README.md` and `docs/event-catalog/README.md`.

## Concepts and architecture

**Topics** (`infrastructure/kafka/topics.yaml`, owned by `event-driven-engineer`):

| Kind | Name | Key | Partitions (start) | Retention |
|---|---|---|---|---|
| Facts | `cf.<aggregate>.events.v<major>` | aggregate ID | 6 | 7 days (14 for order) |
| Commands | `cf.<aggregate>.commands.v<major>` | target aggregate ID | 6 | 3 days |
| DLT | `<topic>.<consumer>.dlt` | original key | 1 | 30 days |

`min.insync.replicas=2`, replication factor 3 in clusters (1 locally).

**Delivery semantics**

- Producer side is Debezium (outbox) — at-least-once, may duplicate on connector restart.
- Consumer side: at-least-once; **commit offsets only after the DB transaction commits**.
- Effectively-once processing = at-least-once delivery + idempotent consumer (inbox).

**Event identity:** `metadata.eventId` (UUID) is created by the producer when the outbox row
is written and is also the `id` header. It is stable across redeliveries and is the inbox key.

**Ordering:** guaranteed per partition, so all events of one aggregate share its key
(`orderId`, `sku`, `paymentId`). Never rely on ordering across aggregates or topics; use
state checks (`status`) and versions.

**Consumer groups:** one group per consuming service (`inventory-service`). Scale by
adding instances up to the partition count.

## Step-by-step workflow

1. Add the event/command to `docs/event-catalog/README.md` and the schema to
   `contracts/events/` (`schema-evolution`).
2. Declare the topic (name, partitions, retention, compaction no) in
   `infrastructure/kafka/`.
3. Producer: write outbox rows with the right `topic` and `aggregate_id`
   (`transactional-outbox`).
4. Consumer: implement with manual commits, inbox, retry/DLT, trace extraction.
5. Add lag and DLT alerts (`observability`).
6. Test with Testcontainers Kafka: duplicates, reordering across keys, poison message.

## Practical code examples

Spring Kafka consumer (inventory commands → here a Kotlin example for order-service
consuming replies):

```kotlin
@Configuration
class KafkaConsumerConfig {
    @Bean
    fun kafkaListenerContainerFactory(
        cf: ConsumerFactory<String, SpecificRecord>,
        errorHandler: DefaultErrorHandler,
    ) = ConcurrentKafkaListenerContainerFactory<String, SpecificRecord>().apply {
        consumerFactory = cf
        containerProperties.ackMode = ContainerProperties.AckMode.RECORD   // commit after listener returns
        setCommonErrorHandler(errorHandler)                                 // see retry-and-dead-letter-queue
        setConcurrency(3)
    }
}

@Component
class InventoryRepliesListener(private val handle: HandleInventoryReply) {
    @KafkaListener(topics = ["cf.inventory.events.v1"], groupId = "order-service")
    fun on(record: ConsumerRecord<String, SpecificRecord>) {
        handle(record.value(), eventId = record.headers().lastHeader("id").value().decodeToString())
        // HandleInventoryReply is @Transactional: inbox + saga update + outbox.
        // The listener returns only after commit, so the offset is committed after the DB tx.
    }
}
```

Consumer properties (`application.yml`):

```yaml
spring.kafka.consumer:
  enable-auto-commit: false
  auto-offset-reset: earliest
  key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
  value-deserializer: org.springframework.kafka.support.serializer.ErrorHandlingDeserializer
  properties:
    spring.deserializer.value.delegate.class: io.confluent.kafka.serializers.KafkaAvroDeserializer
    specific.avro.reader: true
    isolation.level: read_committed
    max.poll.records: 100
```

Go consumer with franz-go (`github.com/twmb/franz-go/pkg/kgo`):

```go
func (c *CommandConsumer) Run(ctx context.Context) error {
	cl, err := kgo.NewClient(
		kgo.SeedBrokers(c.cfg.Brokers...),
		kgo.ConsumerGroup("inventory-service"),
		kgo.ConsumeTopics("cf.inventory.commands.v1"),
		kgo.DisableAutoCommit(),
		kgo.FetchIsolationLevel(kgo.ReadCommitted()),
	)
	if err != nil {
		return fmt.Errorf("kafka client: %w", err)
	}
	defer cl.Close()

	for {
		fetches := cl.PollFetches(ctx)
		if ctx.Err() != nil {
			return nil // shutting down; uncommitted records will be redelivered
		}
		if errs := fetches.Errors(); len(errs) > 0 {
			return fmt.Errorf("fetch: %v", errs)
		}
		var processed []*kgo.Record
		for _, r := range fetches.Records() {
			// handle = inbox + business tx + outbox. It retries transient errors itself and
			// sends permanent failures to the DLT (retry-and-dead-letter-queue), so an error
			// here means "cannot continue safely".
			if err := c.handle(ctx, r); err != nil {
				_ = cl.CommitRecords(context.WithoutCancel(ctx), processed...) // keep progress
				return fmt.Errorf("handle %s/%d@%d: %w", r.Topic, r.Partition, r.Offset, err)
			}
			processed = append(processed, r)
		}
		if err := cl.CommitRecords(ctx, processed...); err != nil {
			return fmt.Errorf("commit: %w", err)
		}
	}
}
```

Never commit a record that comes *after* a failed one in the same partition — that skips
the failed message. Returning the error stops the consumer; the supervisor restarts it and
the uncommitted record is redelivered.

Topic declaration (`infrastructure/kafka/topics.yaml`, applied by an init job):

```yaml
- name: cf.order.events.v1
  partitions: 6
  config: { retention.ms: 1209600000, min.insync.replicas: 2, cleanup.policy: delete }
- name: cf.inventory.commands.v1
  partitions: 6
  config: { retention.ms: 259200000, min.insync.replicas: 2 }
```

## Recommended project structure

```text
contracts/events/<aggregate>/*.avsc
infrastructure/kafka/topics.yaml, broker and Schema Registry config
services/<svc>/.../adapters/in/messaging/      listeners/consumers
services/<svc>/.../adapters/out/messaging/     outbox writer (no direct producers for domain events)
```

## Best practices

- Key by aggregate ID; never null keys for domain events.
- Small, self-describing events with metadata; consumers fetch nothing synchronously to
  understand an event.
- `auto-offset-reset: earliest` for new groups so nothing is skipped.
- Bound `max.poll.records` × processing time below `max.poll.interval.ms`.
- Alert on consumer lag and DLT depth per group.
- Create topics explicitly; disable auto topic creation on brokers.

## Anti-patterns

- Producing domain events directly from use cases (dual write).
- Auto-commit enabled.
- Using Kafka as a request/response RPC with blocking waits.
- One topic per event type with random keys (loses per-aggregate ordering).
- Consumers that depend on events arriving in a global order.

## Failure scenarios

| Scenario | Effect | Handling |
|---|---|---|
| Consumer crash after DB commit, before offset commit | Redelivery | Inbox dedupe. |
| Connector restart | Duplicate events | Same `eventId` → inbox dedupe. |
| Rebalance mid-batch | Records reassigned | Commit only processed records; idempotency. |
| Poison message | Partition blocked | Bounded retries → DLT. |
| Broker unavailable | Fetch errors | Client retries; readiness probe fails after threshold; outbox buffers producer side. |

## Testing strategy

- Testcontainers Kafka + Schema Registry for listener integration tests.
- Duplicate test: publish the same record twice → one side effect.
- Ordering test: events for one key processed in order; different keys in parallel.
- Poison message test: lands in DLT, partition continues.

## Definition of Done

- Topic declared with key, partitions and retention; catalog updated.
- Consumer commits after the transaction; idempotent via inbox; retry/DLT configured.
- Lag and DLT metrics exposed.
- Duplicate and poison-message tests pass.
