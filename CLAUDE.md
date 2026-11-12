# CommerceFlow — Claude Code Guide

CommerceFlow is a **modular monorepo** (ADR-0004): one Git repository containing many
**independently deployable microservices**. A monorepo, not a monolith — the repository
is shared, the services are not.

## Layout

| Path | Contents |
|---|---|
| `services/<name>-service/` | One bounded context each, with its own build, tests, Dockerfile and database |
| `apps/admin-web`, `apps/storefront-web` | React + TypeScript frontends, each with its own build |
| `contracts/events` · `openapi` · `schemas` | The only shared artifacts: Avro events, OpenAPI specs, shared value schemas |
| `infrastructure/` | docker, postgres, kafka, debezium, redis, monitoring, kubernetes |
| `tests/` | Cross-service tests: integration, contract, e2e, performance, resilience |
| `docs/` | architecture, adr, event-catalog, runbooks |
| `backlog/BACKLOG.md` | Engineering backlog (IDs `CF-nnn`) |
| `scripts/` | Repository-level helper scripts |
| `docker-compose.yml` | Local stack (placeholder until CF-005) |

Every service and app folder has its own `CLAUDE.md`. Read it before changing that folder.

## Services

| Service | Context | Language |
|---|---|---|
| product-service | Catalog | Kotlin + Spring Boot |
| order-service | Ordering, saga orchestrator | Kotlin + Spring Boot |
| inventory-service | Inventory | Go |
| payment-service | Payments | Kotlin + Spring Boot |
| customer-service | Customer | Kotlin + Spring Boot |
| pricing-service | Pricing | Kotlin + Spring Boot |
| shipping-service | Fulfilment | Go |
| notification-service | Notification | Go |
| admin-web, storefront-web | UI | React + TypeScript |

Decided in ADR-0003. Ports and databases: `docs/architecture/service-catalog.md`.

## Independence rules (non-negotiable)

- **Build:** each service/app has its own build file and wrapper in its folder. There is
  no root build that compiles services together.
- **Code:** never import, reference or copy code across `services/*` or `apps/*`
  folders. No shared domain or utility libraries. Only `contracts/` is shared, and each
  service generates its own code from it.
- **Data:** each service owns its PostgreSQL database. Never read or write another
  service's database, tables or Redis keys.
- **Integration:** Kafka events (outbox + Debezium, inbox on the consumer side) or
  explicit HTTP APIs defined in `contracts/openapi/`.
- **Tests:** a service's tests run from its own folder. Anything needing more than one
  service goes in `tests/`.
- **Deployment:** one image, Helm release and CI pipeline per service.

## Making changes

1. **Keep a change scoped.** Prefer one service per commit. When a change spans services,
   say which services it touches and why.
2. **Contracts first, compatibility always.** Services deploy separately, so a single
   commit can still break production. Order: compatible contract change → consumers
   tolerate old and new → producer → remove old shape only in a new major version.
   `/implement-feature` plans it with the `commerce-architect`.
3. **Reference the backlog ID** (`CF-012`) in commit messages.
4. `powershell -File scripts/affected-components.ps1 [base]` shows which services and
   apps a change touches (including consumers of changed contracts).

## Workflows (skills invoked with `/name`)

`/implement-feature` · `/create-service` · `/create-api` · `/create-domain-event` ·
`/write-tests` · `/run-e2e` · `/architecture-review` · `/code-review` ·
`/debug-event-flow` · `/database-migration-review` · `/security-audit` ·
`/prepare-pull-request`. Details: `docs/workflow-catalog.md`. There is no separate
`.claude/commands/` mechanism; everything is a skill.

## Hooks

Configured in `.claude/settings.json`, documented in `docs/hook-catalog.md`: destructive
command protection, secret detection, formatting validation, architecture documentation
checks and test reminders. Test them with
`powershell -File .claude/hooks/tests/Test-Hooks.ps1`.

## Hard boundaries

- Claude never pushes, merges PRs, deploys, deletes data or runs destructive migrations.
  No remote has been supplied. `.claude/hooks/guard-destructive-commands.ps1` enforces
  this (deny) and asks before local irreversible commands.
- Read a file before overwriting it.
- Do not claim something works unless it was built and tested in this session. Every
  service and app is still a documentation-only scaffold.

## Engineering principles

DDD with explicit bounded contexts · Clean Architecture (dependencies point inward,
domain has no framework imports) · SOLID · database per service · event-driven
integration · transactional outbox + Debezium CDC · inbox pattern for idempotent
consumers · sagas orchestrated by order-service · CQRS only where justified (catalog
read model, order history) · OpenTelemetry tracing across HTTP and Kafka.

Details: `docs/architecture/overview.md`.

## Where things live

| Need | Location |
|---|---|
| Architecture, context map, saga flow | `docs/architecture/overview.md` |
| Decisions | `docs/adr/` |
| Events: who produces and consumes what | `docs/event-catalog/README.md` |
| Event schema rules | `contracts/events/README.md` |
| Claude agents, skills, hooks | `.claude/` |
| Workflow skills | `docs/workflow-catalog.md` |
| Hooks | `docs/hook-catalog.md` |
| Agent team, ownership and collaboration rules | `docs/agent-catalog.md` |
| Engineering skills (how to build each part) | `docs/skill-catalog.md` |
