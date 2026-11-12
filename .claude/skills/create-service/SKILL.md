---
name: create-service
description: Workflow to add a new independently deployable CommerceFlow microservice under services/ - boundary check and ADR, language choice, folder scaffold with its own build, outbox/inbox baseline, database bootstrap, Debezium connector, Compose entry, CI workflow and catalog updates. Use only when the user explicitly asks for a new service.
argument-hint: "<name>-service <kotlin|go> <bounded context and responsibility>"
disable-model-invocation: true
---

# create-service

## Purpose

Create a service that builds, tests, ships and scales on its own from day one, without
introducing shared code or shared data.

## Invocation

```text
/create-service fraud-service kotlin "Fraud screening of orders before payment authorization"
```

Manual only (`disable-model-invocation: true`): creating a service is an architecture
decision.

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Service name | yes | kebab-case ending in `-service`; must not exist in `services/` |
| Language | yes | `kotlin` (Spring Boot) or `go`; ADR-0003 lists current assignments |
| Responsibility / bounded context | yes | one sentence |
| Events produced/consumed, HTTP API | no | derived in step 2 if missing |

## Required context

Root `CLAUDE.md`, ADR-0003, ADR-0004, `docs/architecture/overview.md`,
`docs/architecture/service-catalog.md` (next free port), `docs/event-catalog/README.md`.

## Relevant agents

`commerce-architect` (boundary + ADR), `kotlin-backend-engineer` or
`golang-backend-engineer` (scaffold), `database-engineer` (database bootstrap),
`event-driven-engineer` (topics, connector), `devops-engineer` (Dockerfile, Compose, CI),
`code-reviewer`.

## Relevant skills

`microservice-design`, `domain-driven-design`, `clean-architecture`, `kotlin-springboot` /
`golang-development`, `postgresql-design`, `transactional-outbox`, `idempotent-consumer`,
`debezium-cdc`, `docker-kubernetes`, `github-actions-cicd`, `architecture-decision-records`.

## Execution steps

1. **Boundary check** with `commerce-architect`: does an existing context own this? If
   yes, stop and propose extending it. If no, draft ADR `NNNN-add-<name>.md` (Proposed).
2. **Design**: owned data, events, commands, API, port, database name `<name>_db`.
   Present to the user; continue only after approval.
3. **Scaffold** (language engineer) in `services/<name>/`: README, CLAUDE.md, own build
   (Gradle wrapper or `go.mod` + Makefile), Clean Architecture packages, health/metrics,
   architecture test, Flyway/migrate baseline with outbox and inbox tables.
4. **Database bootstrap** (`database-engineer`): `infrastructure/postgres/init/<short>.sql`
   (database, migrator/app/cdc roles, publication after migration).
5. **Messaging** (`event-driven-engineer`): topics in `infrastructure/kafka/`, connector
   `infrastructure/debezium/<short>-outbox.json`, event catalog rows.
6. **Platform** (`devops-engineer`): Dockerfile with `contracts` build context, Compose
   entry, Helm values, `.github/workflows/<name>.yml` with path filters.
7. **Catalogs**: service catalog row, agent-catalog ownership row, ADR index.
8. **Verify** (below), then `code-review`.

## Validation steps

- From `services/<name>/`: `./gradlew build` or `make lint test build` passes.
- `docker build --build-context contracts=contracts services/<name>` succeeds.
- `docker compose config` passes with the new entry.
- No file outside the new folder, `infrastructure/`, `contracts/`, `docs/`, `.github/`
  and `docker-compose.yml` changed.
- Stop hook A2 quiet (service listed in the service catalog).

## Expected output

New service folder tree, list of infrastructure/catalog files changed, ADR path, build and
image results, and remaining TODOs as backlog items.

## Failure handling

| Situation | Action |
|---|---|
| Responsibility already owned elsewhere | Stop; recommend extending that service. |
| Port or database name conflict | Pick the next free value from the service catalog. |
| Build cannot run (tooling missing locally) | Report exactly what was not verified; leave the service marked "scaffold" in its README. |
| User has not accepted the ADR | Keep ADR `Proposed`; the service may exist but is not wired into CI deploys. |
