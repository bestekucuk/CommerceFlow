---
name: database-migration-review
description: Workflow to review CommerceFlow database migrations (Flyway and golang-migrate) before they ship - lock levels and duration, data loss, backward compatibility with the running version, expand/contract sequencing, concurrent index rules, backfill safety, rollback and roll-forward risk - and verify them against a disposable PostgreSQL. Never runs migrations against shared databases. Use whenever a migration file is added or changed.
argument-hint: "[migration file | service]"
---

# database-migration-review

## Purpose

Catch migrations that would lock hot tables, lose data or break the version still running
during a rolling deploy.

## Invocation

```text
/database-migration-review                       # all new/changed migration files in the diff
/database-migration-review services/order-service
```

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| File or service | no | default: migrations changed in `git diff HEAD` |

## Required context

The service's full migration history, persistence adapter queries, `CLAUDE.md`; skills
`database-migrations` and `postgresql-design`; expected table sizes (ask if unknown).

## Relevant agents

`database-engineer` (performs the review), `code-reviewer` (independent second check),
the service's language engineer (application compatibility).

## Relevant skills

`database-migrations`, `postgresql-design`, `transaction-management`,
`transactional-outbox` (outbox/inbox tables).

## Execution steps

1. **Collect** migrations: `git diff HEAD --name-only | grep -E 'db/migration/|/migrations/'`.
2. **Per statement classify** lock and risk:

   | Statement | Lock | Risk |
   |---|---|---|
   | `ADD COLUMN` nullable, no default / constant default | ACCESS EXCLUSIVE (brief) | low |
   | `ADD COLUMN ... DEFAULT volatile()` | ACCESS EXCLUSIVE + rewrite | high |
   | `ALTER COLUMN TYPE` (non-binary-compatible) | ACCESS EXCLUSIVE + rewrite | high |
   | `SET NOT NULL` without validated CHECK | ACCESS EXCLUSIVE + full scan | high |
   | `ADD CONSTRAINT ... NOT VALID` then `VALIDATE` | SHARE UPDATE EXCLUSIVE for validate | low |
   | `CREATE INDEX` (non-concurrent) | SHARE (blocks writes) | high on large tables |
   | `CREATE INDEX CONCURRENTLY` | none blocking writes; not in a transaction | low |
   | `DROP COLUMN/TABLE`, `RENAME` | ACCESS EXCLUSIVE | **data loss / compatibility** |
   | `UPDATE`/`DELETE` of many rows | row locks, WAL volume | high (batch it) |

3. **Compatibility**: would the currently deployed application version still work after
   this migration (reads/writes columns that are dropped, renamed or newly NOT NULL)?
4. **Sequencing**: is this the right expand/contract step? Is the contract step deferred?
5. **Safety settings**: `SET lock_timeout`, `statement_timeout`; Flyway `.sql.conf` with
   `executeInTransaction=false` for concurrent indexes.
6. **Rollback**: production rolls forward — is a forward fix possible? Go `.down.sql` is
   local-only; never relied on in production.
7. **Verify** against a disposable database (Testcontainers test or a throwaway container):
   apply from empty, and from the previous version with seeded data; run repository tests.
8. **Report**.

## Validation steps

- Every statement has a lock/risk classification.
- Fresh and upgrade migration runs succeeded on a disposable database (or reason stated).
- No destructive statement without an explicit, user-approved contract step.
- The guard hook prevented any `flyway clean`/`migrate down` (none were attempted).

## Expected output

```markdown
## Migration review — services/order-service
| File | Statement | Lock | Risk | Verdict |
|---|---|---|---|---|
| V7__add_channel.sql | ADD COLUMN channel text | brief ACCESS EXCLUSIVE | low | ok |
| V8__idx.sql | CREATE INDEX (non-concurrent) on customer_order (~5M rows) | SHARE | high | change: CONCURRENTLY in own script + .conf |
Compatibility with running version: ok
Verified: fresh ✅ upgrade-from-V6 ✅ (Testcontainers, postgres:16-alpine)
```

## Failure handling

| Situation | Action |
|---|---|
| Table size unknown | Assume large; require the safe variant. |
| Destructive statement required | Split into expand/contract; contract needs explicit user approval and its own release. |
| No Docker | Static review only; mark verification as not run. |
| Edited an already-applied migration | Blocking: restore it; add a new migration instead. |
