# 0005. Database per service

- Status: Proposed
- Date: 2026-11-12
- Deciders: project owner, commerce-architect
- Affected areas: `services/*`, `infrastructure/postgres`

## Context

Eight services own separate business capabilities (ADR-0004). If two services share
tables, a schema change in one forces a coordinated release of the other, and invariants
can be broken by a service that does not own them. Some data (prices, product names, stock
availability) is needed by several services.

## Decision

- Each service owns exactly one PostgreSQL database, `<short>_db` (e.g. `order_db`), with
  its own roles: `<short>_migrator` (DDL), `<short>_service` (DML), `<short>_cdc`
  (replication, read on `outbox`).
- No other service connects to it. `CONNECT` is revoked from `PUBLIC`.
- No cross-database foreign keys, views, `dblink` or `postgres_fdw`.
- Data needed elsewhere is shared through events (consumers keep local projections) or
  through the owner's HTTP API.
- Redis data is also owned per service (key prefix `<short>:`); it is never a source of
  truth.
- Locally, all databases may run on one PostgreSQL instance; ownership is enforced by
  roles, not by instance boundaries. Production topology is decided with CF-004.

## Alternatives considered

- **Shared database, schema per service** — easy joins, but no isolation of schema
  changes, load or failures; ownership enforced only by convention.
- **Shared read replicas for reporting** — tempting for analytics; would couple consumers
  to internal schemas. Reporting needs are handled later by a separate analytics pipeline
  fed by events (not yet planned).

## Consequences

- Cross-service queries become event-fed projections or API calls; eventual consistency
  must be visible in UX (e.g. "price updating").
- More databases and roles to provision and back up (`docs/architecture/disaster-recovery.md`).
- Each service can choose its own schema evolution pace (`migration-strategy.md`).
