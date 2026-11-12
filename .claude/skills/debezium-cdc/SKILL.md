---
name: debezium-cdc
description: Configure and operate Debezium change data capture for CommerceFlow outboxes - PostgreSQL logical replication (wal_level, pgoutput, publications), replication slots and their monitoring, the Outbox Event Router SMT, header mapping, byte pass-through of Avro payloads, heartbeats, snapshots and connector recovery. Use when adding a connector for a service or diagnosing CDC lag.
---

# Debezium CDC

## Purpose

Move outbox rows from each service's PostgreSQL WAL to Kafka reliably, with one connector
per service, without the services ever talking to Kafka for domain events.

## When to use

- A service starts publishing events (new connector).
- Connector failures, lag, or growing WAL on a database.
- Upgrading Debezium or PostgreSQL.

## Prerequisites

- `transactional-outbox` (table schema), `kafka-event-driven`.
- Kafka Connect with Debezium PostgreSQL connector (2.x) in Compose/Kubernetes.
- Files: `infrastructure/postgres/` (replication setup, `database-engineer`) and
  `infrastructure/debezium/` (connectors, `event-driven-engineer`).

## Concepts and architecture

```text
service tx ──> outbox INSERT ──> WAL ──(pgoutput, slot cf_<svc>_slot)──> Debezium connector
   ──> Outbox Event Router SMT ──> topic from `topic` column, key = aggregate_id,
       headers id / eventType / traceparent, value = payload bytes ──> Kafka
```

- **Logical replication:** `wal_level=logical`; Debezium uses the built-in `pgoutput` plugin.
- **Publication:** limits capture to `outbox` only: `CREATE PUBLICATION cf_<svc>_outbox FOR TABLE outbox;`
- **Replication slot:** one per connector. PostgreSQL retains WAL until the slot confirms
  it — a stopped connector makes WAL grow without bound. **Monitor it.**
- **Offsets:** stored by Kafka Connect in its offsets topic; on restart, Debezium resumes
  from the last committed LSN → possible duplicates (consumers are idempotent).
- **Snapshots:** not needed for an outbox (`snapshot.mode=no_data`; older versions: `never`).
- **Heartbeats:** low-traffic databases need `heartbeat.interval.ms` so the slot advances.

## Step-by-step workflow

1. PostgreSQL (once per instance): `wal_level=logical`, `max_replication_slots` and
   `max_wal_senders` ≥ number of connectors + 2, `max_slot_wal_keep_size` as a safety cap.
2. Per service database: create the CDC role, grant `SELECT` on `outbox`, create the
   publication (in `infrastructure/postgres/init/<svc>.sql`).
3. Create `infrastructure/debezium/<svc>-outbox.json` from the reference connector.
4. Register: `curl -X PUT -H 'Content-Type: application/json' --data @infrastructure/debezium/order-outbox.json http://localhost:8093/connectors/order-outbox/config`
   (Kafka Connect REST is mapped to host port 8093 locally; 8083 is inventory-service).
5. Verify: connector `RUNNING`, a test outbox insert appears on the topic with headers.
6. Add slot-lag and connector-state alerts (`observability`).

## Practical code examples

PostgreSQL settings (`infrastructure/postgres/postgresql.conf` fragment):

```conf
wal_level = logical
max_replication_slots = 16
max_wal_senders = 16
max_slot_wal_keep_size = 10GB      # cap WAL retention; a slot beyond it is invalidated
```

Per-service CDC setup (`infrastructure/postgres/init/order.sql`, continued):

```sql
\connect order_db
CREATE ROLE order_cdc WITH LOGIN REPLICATION PASSWORD :'order_cdc_password';
GRANT SELECT ON outbox TO order_cdc;                     -- after the outbox migration ran
CREATE PUBLICATION cf_order_outbox FOR TABLE outbox;
CREATE TABLE debezium_heartbeat (id int PRIMARY KEY, ts timestamptz);
GRANT INSERT, UPDATE ON debezium_heartbeat TO order_cdc;
```

The outbox table is created by the service's migration; run publication/grant steps after
it (a post-migration script or a migration owned by the service that does only the grant).

Connector: see `reference/outbox-connector.json` in this skill folder. Key settings:

| Setting | Value | Why |
|---|---|---|
| `plugin.name` | `pgoutput` | built into PostgreSQL |
| `publication.name` / `publication.autocreate.mode` | `cf_order_outbox` / `disabled` | capture only `outbox` |
| `slot.name` | `cf_order_slot` | stable, one per connector |
| `table.include.list` | `public.outbox` | |
| `transforms.outbox.route.by.field` | `topic` | destination per row |
| `transforms.outbox.route.topic.replacement` | `${routedByValue}` | topic column holds the full name |
| `transforms.outbox.table.field.event.key` | `aggregate_id` | per-aggregate ordering |
| `transforms.outbox.table.fields.additional.placement` | `type:header:eventType,trace_parent:header:traceparent` | headers for consumers and tracing |
| `value.converter` | `org.apache.kafka.connect.converters.ByteArrayConverter` | pass Avro bytes through untouched |
| `heartbeat.interval.ms` + `heartbeat.action.query` | `10000` + upsert into `debezium_heartbeat` | keep slot advancing |

Slot lag monitoring query:

```sql
SELECT slot_name, active,
       pg_size_pretty(pg_wal_lsn_diff(pg_current_wal_lsn(), confirmed_flush_lsn)) AS lag,
       wal_status
FROM pg_replication_slots;
```

Connector status:

```bash
curl -s http://localhost:8093/connectors/order-outbox/status
```

Restart a failed task:

```bash
curl -s -X POST http://localhost:8093/connectors/order-outbox/tasks/0/restart
```

## Recommended project structure

```text
infrastructure/postgres/postgresql.conf          logical replication settings
infrastructure/postgres/init/<svc>.sql           roles, publication, heartbeat table
infrastructure/debezium/<svc>-outbox.json        one connector per service
.claude/skills/debezium-cdc/reference/outbox-connector.json   template
```

## Best practices

- One connector, one slot, one publication per service database.
- Never share a CDC role across services.
- Use `max_slot_wal_keep_size` in every environment to protect disk.
- Pin Debezium and Connect versions; upgrade with a staged connector restart.
- Keep connectors declarative (files in git) and apply them with an idempotent `PUT`.

## Anti-patterns

- Capturing business tables directly ("CDC as integration") — leaks internal schema.
- Leaving an unused slot after deleting a connector (`SELECT pg_drop_replication_slot(...)`).
- Letting the router infer schemas from JSON when contracts are Avro.
- Running the connector with the database owner role.

## Failure scenarios

| Scenario | Symptom | Handling |
|---|---|---|
| Connector stopped | Slot lag grows, WAL disk grows | Alert (> 1 GB or > 5 min), restart task, investigate error. |
| Slot invalidated (`wal_status = lost`) | Connector fails to resume | Recreate slot; events written while lost must be recovered from the outbox table (it still holds them if cleanup retention > outage) — re-insert as new rows or replay via a one-off connector with `snapshot.mode=initial` filtered by time. |
| Duplicate events after restart | Same `id` twice on topic | Expected; consumers dedupe via inbox. |
| Schema/publication missing after migration | Connector error "publication does not exist" | Run the post-migration CDC script. |
| Database failover | Slot not on new primary (PG < 17) | Recreate slot; accept duplicates from replay; prefer failover slots on PG 17+. |

## Testing strategy

- `tests/integration`: Compose with PostgreSQL + Connect; insert an outbox row; consume the
  topic; assert key, headers, payload bytes equal to the row.
- Restart test: stop connector, insert rows, start it, assert all rows delivered (and
  duplicates tolerated).
- Lag alert test in staging: pause connector, verify alert fires.

## Definition of Done

- Publication, CDC role, heartbeat table and slot exist for the service.
- Connector file committed and registered; status `RUNNING`.
- Topic routing, key, headers and byte pass-through verified end to end.
- Slot lag and connector state monitored with alerts.
