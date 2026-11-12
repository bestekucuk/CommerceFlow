---
name: retry-and-dead-letter-queue
description: Handle failing Kafka messages in CommerceFlow - classify transient vs permanent errors, bounded exponential backoff, blocking vs non-blocking retries and their ordering trade-off, dead-letter topics with diagnostic headers, alerting, and safe DLQ inspection and replay. Use when configuring consumer error handling or recovering messages from a DLT.
---

# Retry and dead-letter queue

## Purpose

A bad message must never block a partition forever, and a temporary outage must never
lose a message. Retries handle the temporary; the dead-letter topic (DLT) parks the
permanent for humans.

## When to use

- Configuring any consumer's error handling.
- Alerts on DLT depth; replaying messages after a fix.

## Prerequisites

- `kafka-event-driven`, `idempotent-consumer`.
- Runbook location: `docs/runbooks/` (DLT replay runbook, CF-023).

## Concepts and architecture

**Classification**

| Class | Examples | Action |
|---|---|---|
| Transient | DB timeout, connection refused, `40001`, 503 from a dependency | Retry with backoff |
| Permanent | Deserialization failure, missing `id` header, validation error, unknown enum without default | DLT immediately |
| Business outcome | Insufficient stock | **Not an error**: emit the failure reply event and commit |

**Blocking retries (CommerceFlow default):** retry in place with exponential backoff
(e.g. 1 s, 2 s, 4 s, 8 s, 16 s — 5 attempts), preserving per-key ordering, then DLT.
**Non-blocking retry topics** keep the partition moving but break ordering per key — only
allowed for consumers whose handling is order-independent (e.g. notification sending).

**DLT:** `<topic>.<consumer>.dlt`, same key, original payload bytes, headers:
original topic/partition/offset, exception class and message, attempt count, first-failure
time. DLT publishing is a direct Kafka send (not via outbox) — it is infrastructure, not a
domain event.

## Step-by-step workflow

1. Define exception classes: `TransientException` vs `PermanentException` (or map library
   exceptions to classes).
2. Configure the consumer's error handler with backoff and DLT recoverer.
3. Mark permanent exceptions as not retryable.
4. Create DLT topics explicitly (`infrastructure/kafka/topics.yaml`).
5. Add metrics: retries, DLT sends; alert on any DLT message for saga topics.
6. Document and test replay.

## Practical code examples

Spring Kafka (blocking retries + DLT):

```kotlin
@Bean
fun errorHandler(template: KafkaTemplate<String, ByteArray>): DefaultErrorHandler {
    val recoverer = DeadLetterPublishingRecoverer(template) { record, _ ->
        TopicPartition("${record.topic()}.order-service.dlt", -1)   // -1: let the partitioner use the key
    }
    val backoff = ExponentialBackOffWithMaxRetries(5).apply {
        initialInterval = 1_000; multiplier = 2.0; maxInterval = 16_000
    }
    return DefaultErrorHandler(recoverer, backoff).apply {
        addNotRetryableExceptions(
            PermanentMessageException::class.java,
            DeserializationException::class.java,
            ValidationException::class.java,
        )
    }
}
```

`DeadLetterPublishingRecoverer` adds `kafka_dlt-original-topic`, `-partition`, `-offset`,
`-exception-fqcn`, `-exception-message` headers. Use a `KafkaTemplate` with
`ByteArraySerializer` (and `ErrorHandlingDeserializer` on the consumer) so the original bytes
are kept even when deserialization failed.

Go (franz-go) bounded retry, then DLT:

```go
func (c *CommandConsumer) handleWithRetry(ctx context.Context, r *kgo.Record) error {
	backoff := time.Second
	for attempt := 1; ; attempt++ {
		err := c.handle(ctx, r)
		switch {
		case err == nil:
			return nil
		case errors.Is(err, ErrPermanent) || attempt == 5:
			return c.toDLT(ctx, r, err, attempt)
		}
		slog.WarnContext(ctx, "transient failure, retrying", "attempt", attempt, "err", err)
		select {
		case <-ctx.Done():
			return ctx.Err() // shutdown: do not commit, will be redelivered
		case <-time.After(backoff):
		}
		backoff = min(backoff*2, 16*time.Second)
	}
}

func (c *CommandConsumer) toDLT(ctx context.Context, r *kgo.Record, cause error, attempts int) error {
	dlt := &kgo.Record{
		Topic: r.Topic + ".inventory-service.dlt",
		Key:   r.Key,
		Value: r.Value,
		Headers: append(r.Headers,
			kgo.RecordHeader{Key: "dlt-original-topic", Value: []byte(r.Topic)},
			kgo.RecordHeader{Key: "dlt-original-partition", Value: []byte(strconv.Itoa(int(r.Partition)))},
			kgo.RecordHeader{Key: "dlt-original-offset", Value: []byte(strconv.FormatInt(r.Offset, 10))},
			kgo.RecordHeader{Key: "dlt-error", Value: []byte(cause.Error())},
			kgo.RecordHeader{Key: "dlt-attempts", Value: []byte(strconv.Itoa(attempts))},
		),
	}
	if err := c.client.ProduceSync(ctx, dlt).FirstErr(); err != nil {
		return fmt.Errorf("publish to DLT: %w", err) // do not commit the original
	}
	c.metrics.DLTSent.WithLabelValues(r.Topic).Inc()
	return nil
}
```

Replay (after the fix is deployed) — inspect first, then re-publish to the original topic
with the same key and headers; the inbox makes accidental double replays harmless:

```bash
# inspect (kcat)
kcat -b localhost:9092 -C -t cf.inventory.commands.v1.inventory-service.dlt -o beginning -e \
  -f 'key=%k offset=%o headers=%h\n'
# replay script (scripts/dlt-replay, CF-023): consume DLT from a stored offset,
# produce to the value of dlt-original-topic, keep key and the "id" header, record progress.
```

## Recommended project structure

```text
infrastructure/kafka/topics.yaml        DLT topics (retention 30 days)
services/<svc>/.../adapters/in/messaging/ErrorHandling.kt | internal/adapters/kafka/retry.go
scripts/dlt-replay                      replay tool (planned)
docs/runbooks/dlt-replay.md             procedure (planned)
```

## Best practices

- Bound retries; total retry time < `max.poll.interval.ms` for blocking retries.
- Business failures are events, not exceptions.
- Alert on DLT arrivals per topic; every DLT message is a bug or an incident.
- Keep original bytes; never "fix" payloads in place in the DLT.
- Replay into the original topic so normal consumers (with inbox) process it.

## Anti-patterns

- Infinite retries (partition stalls).
- Catch-all `try { } catch (e: Exception) { log }` that commits and loses the message.
- Retrying permanent errors (deserialization) five times.
- Non-blocking retry topics for saga participants (ordering broken).
- Manually editing database state instead of replaying.

## Failure scenarios

| Scenario | Outcome |
|---|---|
| DB down 30 s | Blocking retries succeed; no DLT. |
| DB down 10 min | Retries exhausted → DLT; alert; replay after recovery. Consider pausing the container instead (circuit breaker) to avoid flooding the DLT. |
| Poison message | DLT immediately; partition continues. |
| DLT publish fails | Do not commit; message retried; alert on producer errors. |

## Testing strategy

- Integration: transient failure (Toxiproxy `timeout` on PostgreSQL) → processed after
  recovery, no DLT.
- Poison message → DLT with headers, next message processed.
- Replay test: DLT message replayed → processed once (inbox).

## Definition of Done

- Error classes defined; permanent errors not retried.
- Bounded backoff configured; DLT topic declared; headers present.
- DLT metrics and alerts exist.
- Transient, poison and replay tests pass.
