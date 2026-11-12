# Skill Catalog

Reusable engineering skills for CommerceFlow, in `.claude/skills/<name>/SKILL.md`. Every
skill has the same 12 sections: Purpose, When to use, Prerequisites, Concepts and
architecture, Step-by-step workflow, Practical code examples, Recommended project
structure, Best practices, Anti-patterns, Failure scenarios, Testing strategy, Definition
of Done.

## How skills are invoked

- **Automatically:** Claude Code loads a skill when the task matches its `description`.
- **Explicitly:** type `/<skill-name>` (e.g. `/saga-pattern`) or ask "use the saga-pattern
  skill".
- **By agents:** each agent's `Required context` lists the skills it loads
  (`docs/agent-catalog.md`).

Skills describe how to work; they do not contain application code. Code examples in them
are templates that must be adapted and tested in the owning service.

## Architecture

| Skill | Description | Invocation | Relevant agents | Related services | Expected output |
|---|---|---|---|---|---|
| `microservice-design` | Service boundaries, data ownership, sync vs async, independence checklist | `/microservice-design` | commerce-architect | all services | Boundary design, integration choices, new-service footprint, catalog updates |
| `domain-driven-design` | Aggregates, invariants, value objects, domain events, ACLs; domain ≠ contract | `/domain-driven-design` | commerce-architect, kotlin/golang-backend-engineer | all services | Aggregate model with invariants and events, glossary terms, unit tests |
| `clean-architecture` | Layers, ports/adapters, dependency rule, ArchUnit/Go import checks | `/clean-architecture` | kotlin/golang-backend-engineer, code-reviewer, commerce-architect | all services | Correct package layout, ports, passing architecture test |
| `architecture-decision-records` | ADR numbering, template, statuses, supersession, index | `/architecture-decision-records`, `/new-adr` | commerce-architect | repository-wide | ADR file in `docs/adr/`, updated index, backlog follow-ups |

## Backend

| Skill | Description | Invocation | Relevant agents | Related services | Expected output |
|---|---|---|---|---|---|
| `kotlin-springboot` | Independent Gradle Kotlin DSL build, Avro codegen from contracts, Spring config, Flyway, Actuator | `/kotlin-springboot` | kotlin-backend-engineer | product, order, payment, customer, pricing | Service that builds and tests from its folder with standard baseline |
| `golang-development` | Go module per service, slog, context, worker pools, graceful shutdown, table tests | `/golang-development` | golang-backend-engineer | inventory, shipping, notification | Service with `make lint test build` passing and tested shutdown |
| `rest-api-design` | API-first OpenAPI, versioning, problem details, pagination, idempotency keys, ETags | `/rest-api-design` | kotlin/golang-backend-engineer, frontend-engineer | services with HTTP APIs, both apps | Updated spec in `contracts/openapi/`, matching implementation, provider verification |
| `secure-backend-development` | JWT validation, function/object-level authZ, validation, secrets, safe logging | `/secure-backend-development` | kotlin/golang-backend-engineer, security-reviewer | all services | Secured endpoints with negative security tests |

## Database

| Skill | Description | Invocation | Relevant agents | Related services | Expected output |
|---|---|---|---|---|---|
| `postgresql-design` | Database/role ownership, types, constraints, indexes, query plans | `/postgresql-design` | database-engineer, kotlin/golang-backend-engineer | all services | Schema with constraints and justified indexes, checked plans |
| `database-migrations` | Flyway / golang-migrate, expand/contract, concurrent indexes, lock timeouts, backfills | `/database-migrations` | database-engineer, kotlin/golang-backend-engineer | all services | Backward-compatible migrations with fresh and upgrade tests |
| `transaction-management` | Isolation levels, optimistic/pessimistic locking, conditional updates, retries | `/transaction-management` | database-engineer, kotlin/golang-backend-engineer | all services (esp. inventory, order, payment) | Correct transaction boundaries, concurrency tests |

## Event-driven

| Skill | Description | Invocation | Relevant agents | Related services | Expected output |
|---|---|---|---|---|---|
| `kafka-event-driven` | Topics, keys, at-least-once, event identity, consumer groups, commits after tx, lag | `/kafka-event-driven` | event-driven-engineer, kotlin/golang-backend-engineer | all services | Topic declaration, consumer with safe commits, duplicate/poison tests |
| `transactional-outbox` | Outbox schema, atomic writes, Avro payloads, routing, trace capture, cleanup | `/transactional-outbox` | event-driven-engineer, kotlin/golang-backend-engineer, database-engineer | all producing services | Outbox table and writer, atomicity tests |
| `debezium-cdc` | Logical replication, publications, slots, Outbox Event Router, heartbeats, recovery | `/debezium-cdc` | event-driven-engineer, database-engineer, devops-engineer | all producing services | Connector config (`reference/outbox-connector.json`), slot monitoring |
| `schema-evolution` | Avro BACKWARD compatibility, subjects, major versions, rollout order | `/schema-evolution` | event-driven-engineer, code-reviewer | all producers/consumers | Valid schema change, updated event catalog, compatibility check |
| `saga-pattern` | Orchestrated order saga, state table, timeouts, compensations, correlation | `/saga-pattern` | commerce-architect, event-driven-engineer, kotlin/golang-backend-engineer | order (orchestrator), inventory, payment, shipping | State machine, transitions as local tx, failure/timeout tests |
| `idempotent-consumer` | Inbox table, dedupe by eventId in the same tx, retention | `/idempotent-consumer` | kotlin/golang-backend-engineer, event-driven-engineer | all consuming services | Inbox-backed handlers, duplicate and crash tests |
| `retry-and-dead-letter-queue` | Transient vs permanent errors, backoff, DLT headers, replay | `/retry-and-dead-letter-queue` | event-driven-engineer, kotlin/golang-backend-engineer | all consuming services | Error handler with bounded retries, DLT topics, replay procedure |

## Frontend

| Skill | Description | Invocation | Relevant agents | Related services | Expected output |
|---|---|---|---|---|---|
| `react-typescript` | Vite per app, strict TS, generated API clients, TanStack Query, a11y, Vitest | `/react-typescript` | frontend-engineer | admin-web, storefront-web | Feature with typed API calls, states handled, tests passing |
| `admin-dashboard-development` | Role-gated routes, server-paginated tables, zod forms, ETags, confirmations | `/admin-dashboard-development` | frontend-engineer | admin-web (+ the owning service APIs) | Admin feature respecting service ownership, with tests |

## Testing

| Skill | Description | Invocation | Relevant agents | Related services | Expected output |
|---|---|---|---|---|---|
| `unit-integration-testing` | Test pyramid per service, JUnit 5/AssertJ/MockK, Go table tests, fakes | `/unit-integration-testing` | test-engineer, kotlin/golang-backend-engineer, code-reviewer | all services | Unit + adapter tests runnable from the service folder |
| `testcontainers` | Real PostgreSQL/Kafka/Registry/Toxiproxy in Kotlin and Go tests | `/testcontainers` | test-engineer, kotlin/golang-backend-engineer | all services | Integration tests with pinned images and real migrations |
| `contract-testing` | Pact consumer/provider, provider states, broker, can-i-deploy, Avro checks | `/contract-testing` | test-engineer, frontend-engineer, kotlin/golang-backend-engineer | apps + HTTP providers, all event producers | Pacts, provider verification, deploy gates |
| `playwright-e2e` | App-local and cross-app journeys, role locators, API seeding, async assertions | `/playwright-e2e` | test-engineer, frontend-engineer | admin-web, storefront-web, full stack | E2E specs in `apps/*/tests/e2e` or `tests/e2e` |
| `performance-testing` | k6 workloads, scenarios, SLO thresholds, saga latency, Prometheus export | `/performance-testing` | test-engineer | product, pricing, order, inventory | k6 scripts in `tests/performance`, baseline results |
| `resilience-testing` | Toxiproxy faults, scenario catalogue with expected outcomes, recovery checks | `/resilience-testing` | test-engineer | order, inventory, payment, Debezium/Kafka | Fault-injection tests in services and `tests/resilience` |

## Platform

| Skill | Description | Invocation | Relevant agents | Related services | Expected output |
|---|---|---|---|---|---|
| `docker-kubernetes` | Per-service Dockerfiles with contracts build context, Compose wiring, Helm values | `/docker-kubernetes` | devops-engineer | all services and apps | Images, Compose entries, Helm values; validation passing |
| `github-actions-cicd` | Path-filtered workflow per component, reusable templates, contract checks, gated deploys | `/github-actions-cicd` | devops-engineer | all services and apps | Workflows in `.github/workflows`, linted |
| `observability` | RED/USE, messaging/CDC/business metrics, JSON logs, dashboards, alerts | `/observability` | devops-engineer, kotlin/golang-backend-engineer | all services | Metrics, dashboards, alert rules (`reference/otel-collector.yaml`) |
| `distributed-tracing` | W3C context over HTTP and through outbox → Debezium → Kafka, Go/Java setup | `/distributed-tracing` | devops-engineer, kotlin/golang-backend-engineer | all services | One trace across services for a placed order |
| `security-review` | STRIDE, OWASP API Top 10 mapping, scanners, findings report | `/security-review` | security-reviewer | any changed component | Severity-ranked findings with evidence and owners |
| `code-review` | Boundary checks, architecture rules, tests run, findings and verdict | `/code-review` | code-reviewer | any changed component | Verdict + ranked findings + commands run |

## Reference files

| File | Used by |
|---|---|
| `.claude/skills/debezium-cdc/reference/outbox-connector.json` | Template for `infrastructure/debezium/<svc>-outbox.json` |
| `.claude/skills/observability/reference/otel-collector.yaml` | Template for `infrastructure/monitoring/otel-collector.yaml` |

## Conventions captured across skills

- Local ports: services 8081–8088 (`docs/architecture/service-catalog.md`), Schema Registry
  8090, Kafka Connect REST 8093, apps 5173/5174.
- Outbox columns: `id, aggregate_type, aggregate_id, type, topic, payload (bytea Avro), occurred_at, trace_parent`;
  Debezium routes on `topic`.
- Inbox key: `(message_id, consumer)` with `message_id` = `eventId` = Kafka `id` header.
- No root build, no shared runtime libraries; only `contracts/` is shared.
