---
name: debug-event-flow
description: Workflow to trace a CommerceFlow event or saga step through PostgreSQL, the outbox table, the replication slot and Debezium connector, Kafka topic and headers, consumer group lag, the consumer's inbox and DLT, and the resulting state - read-only, hop by hop, to find where a message stopped. Use when an event did not arrive, arrived twice, or a saga is stuck.
argument-hint: "<eventId | orderId/aggregateId | topic> [service]"
---

# debug-event-flow

## Purpose

Locate exactly which hop of the asynchronous pipeline lost, delayed, duplicated or
rejected a message, using read-only inspection.

## Invocation

```text
/debug-event-flow 0190d1c4-6b8c-7c3e-9f5e-1a2b3c4d5e6f order-service
/debug-event-flow cf.inventory.commands.v1
```

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Identifier | yes | eventId (outbox `id` / Kafka `id` header), aggregate ID (key), or topic |
| Producing service | no | inferred from the event catalog |

## Required context

`docs/event-catalog/README.md`, `docs/architecture/overview.md` (saga), the producer's and
consumer's `CLAUDE.md`, `infrastructure/debezium/<svc>-outbox.json`, local ports from
`docs/architecture/service-catalog.md` (Kafka Connect REST 8093, Schema Registry 8090).

## Relevant agents

`event-driven-engineer` (lead), `database-engineer` (slot/WAL questions), the producer's
and consumer's language engineers (code-level cause), `devops-engineer` (container health).

## Relevant skills

`transactional-outbox`, `debezium-cdc`, `kafka-event-driven`, `idempotent-consumer`,
`retry-and-dead-letter-queue`, `saga-pattern`, `distributed-tracing`, `observability`.

## Execution steps

All commands are read-only. Use the Compose service names; database credentials come from
the user's environment, never typed into commands by Claude.

1. **Producer state** — did the business change commit?
   `docker compose exec postgres psql -U <svc>_service -d <svc>_db -c "SELECT id, status, version FROM <aggregate_table> WHERE id = '<id>'"`
2. **Outbox row** — was the event written?
   `... -c "SELECT id, type, topic, aggregate_id, occurred_at, trace_parent FROM outbox WHERE aggregate_id = '<id>' ORDER BY occurred_at"`
3. **Replication slot** — is CDC keeping up?
   `... -c "SELECT slot_name, active, wal_status, pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag FROM pg_replication_slots"`
4. **Connector** — `curl -s http://localhost:8093/connectors/<svc>-outbox/status` (state,
   task errors).
5. **Kafka record** — present with key and headers?
   `docker compose exec kafka kafka-console-consumer --bootstrap-server kafka:9092 --topic <topic> --from-beginning --property print.key=true --property print.headers=true --timeout-ms 10000 | grep <id>`
   (or `kcat -C -t <topic> -f '%k %h\n' -e | grep <id>`).
6. **Consumer group** — lag and assignment:
   `docker compose exec kafka kafka-consumer-groups --bootstrap-server kafka:9092 --describe --group <consumer-service>`
7. **Inbox** — processed?
   `... -d <consumer>_db -c "SELECT * FROM inbox WHERE message_id = '<eventId>'"`
8. **DLT** — rejected? read `<topic>.<consumer>.dlt` with headers (`dlt-error`,
   `kafka_dlt-exception-message`).
9. **Result state** — consumer's projection/saga row; for sagas: `saga_instance` state and
   `deadline_at`.
10. **Trace** — follow `trace_parent` in Tempo; logs in Loki by `trace_id`.
11. **Conclude**: name the hop, the evidence and the owning agent for the fix.

## Validation steps

- Each hop has a recorded observation (found / not found / value).
- Conclusion is supported by the first hop where the message is missing or wrong.
- No write command was executed (guard hook would deny destructive SQL; Claude also does
  not run INSERT/UPDATE/DELETE during debugging).

## Expected output

```markdown
## Event flow: <id>
| Hop | Observation | OK |
|---|---|---|
| order_db customer_order | CONFIRMED, version 3 | ✅ |
| outbox | OrderConfirmed, topic cf.order.events.v1 | ✅ |
| slot cf_order_slot | active, lag 16 kB | ✅ |
| connector order-outbox | RUNNING | ✅ |
| Kafka cf.order.events.v1 | key=<id>, headers id/eventType/traceparent | ✅ |
| group shipping-service | lag 0 | ✅ |
| shipping inbox | not found | ❌ |
| DLT cf.order.events.v1.shipping-service.dlt | 1 record: DeserializationException | ❌ |
Cause: shipping-service lacks the new optional field's default in its reader schema → fix in shipping-service (golang-backend-engineer); replay DLT after fix.
```

## Failure handling

| Situation | Action |
|---|---|
| Stack not running | Ask before starting; otherwise report which hops could not be inspected. |
| Credentials missing | Ask the user to export them; never hard-code. |
| Message found in DLT | Do not replay automatically; describe the replay procedure (`retry-and-dead-letter-queue`) for the user to approve after the fix. |
| Slot lost (`wal_status = lost`) | Escalate to the user immediately; recovery is a manual runbook step. |
