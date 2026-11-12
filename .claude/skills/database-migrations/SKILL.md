---
name: database-migrations
description: Write safe, backward-compatible database migrations for CommerceFlow services - Flyway for Kotlin, golang-migrate for Go - using expand/contract, concurrent index creation, lock timeouts and batched backfills so each service can be deployed independently with zero downtime. Use whenever a migration is added or reviewed.
---

# Database migrations

## Purpose

Change a service's schema without downtime and without breaking the version that is
still running during a rolling deploy.

## When to use

- Any DDL change in a service database.
- Backfills and data fixes.
- Reviewing migration PRs.

## Prerequisites

- `postgresql-design`; the service's existing migration history.
- Tooling: Flyway (bundled with Spring Boot in Kotlin services), `golang-migrate` CLI or
  library (Go services).

## Concepts and architecture

**Compatibility rule:** during a rolling deploy, version N and N+1 run against the same
schema. Every migration must work with both.

**Expand / contract** — a breaking change becomes several deploys:

| Step | Deploy | Example: rename `email` → `contact_email` |
|---|---|---|
| Expand | 1 | Add `contact_email` nullable; app writes both, reads old. |
| Backfill | 1 (job) | Copy `email` → `contact_email` in batches. |
| Switch | 2 | App reads new, still writes both. |
| Contract | 3 | App stops writing old; migration drops `email`. |

**Locking:** most `ALTER TABLE` forms take `ACCESS EXCLUSIVE`. Always set
`lock_timeout` so a blocked migration fails fast instead of queueing all traffic behind it.

**Naming**

- Flyway: `src/main/resources/db/migration/V<n>__<description>.sql` (versioned),
  `R__<description>.sql` (repeatable views/functions).
- golang-migrate: `migrations/<6-digit>_<description>.up.sql` and `.down.sql`.

## Step-by-step workflow

1. Classify the change: additive-safe, expand, or contract.
2. Write the migration with `SET lock_timeout` and `statement_timeout`.
3. For indexes on existing tables use `CREATE INDEX CONCURRENTLY` in its own,
   non-transactional migration.
4. Separate backfills from DDL; run them in batches.
5. Verify: migrate from empty and from the previous production version (Testcontainers).
6. Verify the previous app version still passes its repository tests against the new
   schema (for expand steps).
7. Document the remaining contract step as a backlog item.

## Practical code examples

Additive, safe (Flyway `V7__add_order_channel.sql`):

```sql
SET lock_timeout = '3s';
SET statement_timeout = '30s';
ALTER TABLE customer_order ADD COLUMN channel text;                 -- nullable, no rewrite
ALTER TABLE customer_order ADD CONSTRAINT customer_order_channel_chk
  CHECK (channel IN ('WEB','ADMIN')) NOT VALID;                     -- no full scan now
```

Validate later (`V8__validate_order_channel.sql`) — takes a weaker lock:

```sql
ALTER TABLE customer_order VALIDATE CONSTRAINT customer_order_channel_chk;
```

Concurrent index in Flyway — needs its own script plus a config file
`V9__customer_order_status_idx.sql.conf`:

```properties
executeInTransaction=false
```

```sql
-- V9__customer_order_status_idx.sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS customer_order_status_idx ON customer_order (status);
```

If a concurrent build fails it leaves an `INVALID` index: drop it (`DROP INDEX
CONCURRENTLY`) and rerun.

Adding `NOT NULL` safely (PostgreSQL ≥ 12 uses a validated CHECK to skip the scan):

```sql
ALTER TABLE customer_order ADD CONSTRAINT customer_order_channel_nn CHECK (channel IS NOT NULL) NOT VALID;
ALTER TABLE customer_order VALIDATE CONSTRAINT customer_order_channel_nn;
ALTER TABLE customer_order ALTER COLUMN channel SET NOT NULL;   -- uses the valid check, no scan
ALTER TABLE customer_order DROP CONSTRAINT customer_order_channel_nn;
```

Batched backfill (run as a job, not inside the migration):

```sql
-- repeat until 0 rows updated
UPDATE customer SET contact_email = email
WHERE id IN (SELECT id FROM customer WHERE contact_email IS NULL AND email IS NOT NULL LIMIT 1000);
```

golang-migrate in a Go service (`migrations/000003_reservation_expiry.up.sql`):

```sql
SET lock_timeout = '3s';
ALTER TABLE reservation ADD COLUMN expires_at timestamptz;
```

```go
// cmd/inventory-service/migrate.go — run as a separate command / init container, not on every replica start
m, err := migrate.New("file://migrations", cfg.MigratorDatabaseURL)
if err != nil {
	return fmt.Errorf("init migrate: %w", err)
}
if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
	return fmt.Errorf("migrate up: %w", err)
}
```

Imports: `github.com/golang-migrate/migrate/v4`, `_ "github.com/golang-migrate/migrate/v4/database/pgx/v5"`,
`_ "github.com/golang-migrate/migrate/v4/source/file"` (URL scheme `pgx5://`).

## Recommended project structure

```text
services/<kotlin-svc>/src/main/resources/db/migration/V<n>__*.sql (+ .sql.conf)
services/<go-svc>/migrations/<n>_*.up.sql / .down.sql
backlog/BACKLOG.md   pending "contract" steps
```

## Best practices

- Run migrations with the migrator role; the app role has DML only.
- One concern per migration; never edit an applied migration (Flyway checksums).
- Kotlin: Flyway runs at startup (single-replica safe via its lock) or as a Kubernetes
  Job; Go: run migrations as a Job/init container.
- Keep down migrations for Go for local use; production rolls forward.
- Write the "contract" step only after the previous release is fully rolled out.

## Anti-patterns

- Rename/drop in the same release that stops using the column.
- `CREATE INDEX` (non-concurrent) on a large live table.
- Backfilling millions of rows in one transaction.
- `ALTER COLUMN TYPE` that rewrites the table during peak traffic.
- Migrations that depend on another service's schema or data.

## Failure scenarios

| Scenario | Symptom | Handling |
|---|---|---|
| Lock queue behind migration | All queries stall | `lock_timeout` aborts; retry off-peak. |
| Concurrent index fails | `INVALID` index left | Drop concurrently, rerun. |
| Migration applied, app rollback | Old app sees new columns | Expand-only migrations make this safe. |
| Checksum mismatch | Flyway refuses to start | Restore the original file; add a new migration. |

## Testing strategy

- Testcontainers: apply all migrations from empty; assert `flyway info`/`migrate version`.
- Upgrade test: apply up to N-1, seed data, apply N, run repository tests.
- Run the previous release's repository tests against the new schema for expand steps.

## Definition of Done

- Migration classified and backward compatible with the running version.
- `lock_timeout` set; concurrent indexes isolated and non-transactional.
- Backfills batched and separate from DDL.
- Fresh and upgrade migration tests pass.
- Contract follow-up recorded when applicable.
