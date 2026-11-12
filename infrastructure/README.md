# Local infrastructure

Status: **implemented for local development** (single node, Docker Compose). Not a
production design: see `docs/architecture/deployment-architecture.md` for the target.
What has actually been verified on a machine is recorded in
[Verification log](#verification-log).

## Components

| Component | Image | Host port (127.0.0.1 only) | Purpose |
|---|---|---|---|
| postgres | `postgres:16.4-alpine` | 15432 (`CF_POSTGRES_HOST_PORT`) | 8 service databases, logical replication for Debezium |
| kafka | `apache/kafka:3.8.0` (KRaft, 1 node) | 9092 (`localhost:9092`); containers use `kafka:29092` | event backbone |
| kafka-init | `apache/kafka:3.8.0` (one-shot) | — | creates topics from `kafka/topics.csv` |
| schema-registry | `confluentinc/cp-schema-registry:7.7.1` | 8090 | Avro schemas, default compatibility BACKWARD |
| connect | `quay.io/debezium/connect:2.7.3.Final` | 8093 | Kafka Connect + Debezium PostgreSQL connector |
| kafka-ui | `provectuslabs/kafka-ui:v0.7.2` | 8095 | browse topics, groups, schemas, connectors |
| redis | `redis:7.4-alpine` | 16379 (`CF_REDIS_HOST_PORT`) | caches; ACL user per owning service |
| otel-collector | `otel/opentelemetry-collector-contrib:0.111.0` | 4317 (gRPC), 4318 (HTTP), 13133 (health) | telemetry intake |
| prometheus | `prom/prometheus:v2.54.1` | 9090 | metrics |
| grafana | `grafana/grafana:11.2.2` | 3000 | dashboards (folder "CommerceFlow") |
| loki | `grafana/loki:3.2.0` | 3100 | logs |
| tempo | `grafana/tempo:2.6.0` | 3200 | traces |
| postgres-exporter, kafka-exporter, redis-exporter | pinned versions in `docker-compose.yml` | — | metrics for dashboards |

Application services are **not** in the Compose file yet.

## Quick start

```bash
powershell -File infrastructure/scripts/up.ps1                 # creates .env on first run, waits for health
powershell -File infrastructure/scripts/health.ps1             # full check table
powershell -File infrastructure/scripts/migrate.ps1 -All       # each service's own migrations + CDC grants
powershell -File infrastructure/scripts/register-connectors.ps1
powershell -File infrastructure/scripts/verify-cdc.ps1 -Service product
powershell -File infrastructure/scripts/down.ps1               # keeps volumes
```

With `make`: `make -C infrastructure up|health|migrate|connectors|verify-cdc|down`.

| UI | URL | Login |
|---|---|---|
| Grafana | http://localhost:3000 | `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` from `.env` |
| Kafka UI | http://localhost:8095 | none (local only) |
| Prometheus | http://localhost:9090 | none |

## Credentials

- `.env.example` (committed) lists every variable with **local-only** values; `up.ps1` copies
  it to `.env` (gitignored). Nothing in compose files, scripts or connector configs contains a
  password; connector files use `${env:<NAME>}` resolved inside Connect.
- PostgreSQL: superuser for bootstrap only; per service **three roles**
  (`<svc>_migrator` DDL/owner, `<svc>_service` DML, `<svc>_cdc` replication for publishers),
  plus `monitoring` (pg_monitor) for the exporter. `CONNECT` on each database is revoked from
  `PUBLIC`, so no service role can open another service's database (checked by `health.ps1`).
- Connect receives only the 7 CDC passwords. Redis: `default` user disabled; users
  `product-service` (`product:*`), `pricing-service` (`pricing:*`), `monitoring` (read-only
  server commands).
- Scripts pass database passwords to `docker compose exec` as `-e PGPASSWORD=…`; they are
  visible in the local process list while the command runs. Acceptable for local
  development only.

## PostgreSQL and Debezium

### WAL

PostgreSQL runs with `wal_level=logical`, so the WAL contains enough information for
logical decoding. `max_replication_slots=16` and `max_wal_senders=16` leave room for 7
connectors. `max_slot_wal_keep_size=2GB` caps how much WAL a stalled slot may retain; beyond
that the slot is **invalidated** (`wal_status = lost`) instead of filling the disk.

### Publications

`postgres/post-migrate.sql` creates `cf_<svc>_outbox` **for the `outbox` table only**,
after the service's own migration created it. Debezium never sees business tables
(`publication.autocreate.mode=disabled`).

### Replication slots

One slot per connector: `cf_<svc>_slot`, created by Debezium on first start. A slot
remembers the last LSN the connector confirmed; PostgreSQL keeps all WAL after it. While a
connector is stopped, slot lag grows (dashboard "PostgreSQL health"). Dropping a slot loses
the CDC position and is a manual, user-approved step (the Claude guard hook denies
`pg_drop_replication_slot`).

### Connector configuration

`debezium/connectors/<svc>-outbox.json` (7 files, one per publishing service; notification
publishes nothing):

| Setting | Value | Why |
|---|---|---|
| `plugin.name` | `pgoutput` | built into PostgreSQL |
| `slot.name` / `publication.name` | `cf_<svc>_slot` / `cf_<svc>_outbox` | one each per service |
| `snapshot.mode` | `no_data` | the outbox needs no initial snapshot |
| `skipped.operations` | `u,d,t` | the outbox is insert-only; cleanup deletes are ignored |
| `transforms` | `io.debezium.transforms.outbox.EventRouter` | outbox row → event |
| `route.by.field` / replacement | `topic` / `${routedByValue}` | the row chooses its topic |
| `table.field.event.key` | `aggregate_id` | Kafka key → per-aggregate ordering |
| additional placement | `type→eventType`, `trace_parent→traceparent`, `aggregate_type→aggregateType` headers; `id` header from `outbox.id` | consumer dedupe and tracing |
| `value.converter` | `io.debezium.converters.BinaryDataConverter` | the service's Avro bytes pass through unchanged (`ByteArrayConverter` failed with `bytea` → `ByteBuffer`, found in the first real run) |

`register-connectors.ps1` PUTs each file (create or update) and skips services whose
publication does not exist yet.

### Offset storage

Kafka Connect runs in distributed mode with internal topics `_connect-configs`,
`_connect-offsets` (source offsets = last LSN processed per connector) and
`_connect-status`, replication factor 1. Connector configs therefore survive Connect
restarts as long as the Kafka volume exists.

### Recovery behaviour

| Situation | What happens |
|---|---|
| Connect restarts | Resumes from the offset in `_connect-offsets`; rows after the last committed offset are re-published → **duplicates possible**; consumers dedupe by `id` (inbox) |
| Kafka down | Connector task retries/fails; WAL is retained by the slot; restart the task (`POST /connectors/<n>/tasks/0/restart`) after Kafka is back |
| Connector stopped for long | Slot lag grows up to 2 GB, then the slot is lost; recovery = recreate slot and re-publish rows still in the outbox (manual) |
| Kafka volume deleted | Connect loses offsets and configs; re-register connectors; the slot position on PostgreSQL still decides what is streamed next |
| PostgreSQL volume deleted | Databases, roles and slots are recreated by the init script on next start; run `migrate.ps1` and `register-connectors.ps1` again |

### Local deviations from the target design

- **No heartbeat.** All databases share one PostgreSQL instance, so an idle database's slot
  retains WAL produced by the others. The target design uses Debezium heartbeats with an
  action query; locally the 2 GB cap is the safety net. If a slot is lost locally, recreate
  it (re-run `register-connectors.ps1` after dropping the connector and slot).
- Topics are pre-created (`kafka-init`); Connect cannot create topics, so an outbox row with
  an undeclared topic fails the connector task — on purpose.

## Kafka

| Item | Local setting |
|---|---|
| Naming | `cf.<aggregate>.events.v<major>`, `cf.<aggregate>.commands.v<major>`, DLT `<topic>.<consumer>.dlt` (`docs/event-catalog/event-naming-conventions.md`) |
| Topics | `kafka/topics.csv`: 9 event/command topics (3 partitions), 14 dead-letter topics (1 partition), `cf.cdc-check.v1` (CDC verification, 1 h retention) |
| Retention | events 7 days (order 14), commands 3 days, DLT 30 days — proposed defaults from `docs/architecture/data-retention-policy.md` |
| Replication | factor 1 everywhere; `min.insync.replicas=1` |
| Auto topic creation | disabled |
| Consumer groups | group id = service name; expected subscriptions in `kafka/consumer-groups.csv`. Groups appear when a consumer connects (none run yet) |
| Health | broker health check (`kafka-broker-api-versions`), `kafka-init` exit code, `health.ps1` topic check |

Re-apply topics after editing the CSV: `docker compose run --rm kafka-init` (creates missing
topics, updates retention; it never deletes topics or reduces partitions).

### Single-node limitations

- No replication: losing the volume loses all events; a broker restart makes everything
  unavailable until it is back.
- Acks and ISR settings cannot reproduce production durability behaviour.
- Partition counts are local choices for testing parallel consumers, not capacity targets.
- KRaft controller and broker share one process.

## Monitoring

Dashboards (`monitoring/grafana/dashboards`, provisioned read-only):

| Dashboard | Shows |
|---|---|
| Infrastructure health | scrape targets up, PostgreSQL/Kafka/Redis reachability, collector intake |
| Kafka health | brokers, topics, under-replicated/leaderless partitions, message rates, DLT growth |
| Consumer lag | lag by group, by topic, per partition; group members |
| PostgreSQL health | up, databases, slots active, slot lag in bytes, size, transactions, connections |

Panels colour only up/down; there are no SLO thresholds (none are defined, CF-025).
Collector pipeline: traces → Tempo, metrics → Prometheus (scrape `otel-collector:8889`),
logs → Loki (OTLP). Grafana datasources link traces ↔ logs.

## Known limitations

- Local only: no TLS, no authentication on Kafka, Kafka UI or Prometheus (bound to
  127.0.0.1).
- Tempo stores traces inside the container (lost on restart); Loki and Prometheus keep 7
  days.
- Debezium Connect metrics (JMX) are not scraped yet; connector state is checked by
  `health.ps1` and visible in Kafka UI.
- Schema Registry has no schemas until CF-002.
- Application services are not wired into Compose yet; their migrations are applied with
  `migrate.ps1` using the same migration files as the services.

## Verification log

Filled in after each verified run on a real machine (date, Docker version, results).

### 2026-11-12 — Windows 10, Docker Desktop (Engine 29.9.3)

| Check | Result |
|---|---|
| `up.ps1` | all 15 containers running; `kafka-init` exit 0 (22 topics created, 2 updated) |
| `health.ps1` | **All infrastructure checks passed**: 8/8 databases, 23/23 roles, cross-database isolation, `wal_level=logical`, 24/24 topics, auto topic creation off, Redis default user disabled, 9/9 Prometheus targets, all HTTP health endpoints |
| `register-schemas.ps1` | `cf.product.events.v1-…ProductCreated` registered (id 1, BACKWARD); `-CheckOnly` → compatible |
| `migrate.ps1 -Service product / inventory` | Flyway V1+V2 and golang-migrate 000001+000002 applied with migrator roles; publications created |
| `verify-cdc.ps1 -Service product` | **first run failed**: connector task FAILED, `ByteArrayConverter is not compatible with ... HeapByteBuffer`. Fixed by `io.debezium.converters.BinaryDataConverter` in all 7 connectors. **Second run passed**: key, `id`/`eventType`/`traceparent` headers and payload bytes match the outbox row. The row written while the task was failed was delivered after the fix (topic offset 2, both rows present) — no loss |
| E2E `tests/integration/run-e2e.ps1` | **PASS** (13.1 s): HTTP → product-service → outbox → Debezium → `cf.product.events.v1` → inventory-service; same correlation id and trace id in both services' JSON logs; one trace with both services in Tempo |
| Consumer restart | inventory stopped gracefully, product created while down, processed after restart; no duplicate re-processing |

Issues found and fixed during this run: corrupted images after a full disk (re-pulled),
host port clashes with another local stack (Postgres/Redis host ports now 15432/16379),
`ADD --chmod` making `/otel` untraversable in the product image, and a `/dev/tcp`
health check that dash does not support (now `curl`).
