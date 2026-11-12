# Tasks

Status legend: ✅ Done = verified in this repository (evidence given) · 🟡 In progress · ⛔ Blocked · ⬜ Not started.
Generated from one data source; IDs `CF-0xx` keep the numbers already used in `docs/`. Snapshot: 2026-11-12.

83 tasks — ✅ Done: 13, 🟡 In progress: 7, ⛔ Blocked: 0, ⬜ Not started: 63

Every task also meets the general [Definition of Done](DEFINITION-OF-DONE.md).

## Phase 1 — Engineering foundation

### CF-001

**Accept or revise ADRs 0005-0011**

| Field | Value |
|---|---|
| Task ID | CF-001 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-01 / F-01 Repository and architecture baseline |
| Owning service or application | `docs` |
| Priority | P0 |
| Dependencies | [CF-031](TASKS.md#cf-031) |
| Required agent | `commerce-architect` |
| Required skills | `architecture-decision-records` |

**Description.** Project owner reviews the Proposed ADRs (database per service, outbox, Debezium, Kafka, saga, gateway/BFF, independent deployment).

**Acceptance criteria**

- Each ADR is Accepted, revised or rejected by the owner
- ADR index reflects the decision

**Test requirements**

- none (decision)

**Definition of Done** — general DoD, plus:

- Owner decision recorded in each ADR

### CF-003

**Contract code generation tooling**

| Field | Value |
|---|---|
| Task ID | CF-003 |
| Status | 🟡 In progress — Kotlin Avro codegen from ../../contracts in product-service (Gradle + Docker build context); Go decodes with the registry writer schema (no codegen); OpenAPI client generation for apps open |
| Epic / feature | CF-EPIC-01 / F-03 Contract code generation |
| Owning service or application | `contracts, services` |
| Priority | P0 |
| Dependencies | [CF-032](TASKS.md#cf-032) |
| Required agent | `event-driven-engineer` |
| Required skills | `schema-evolution`, `kotlin-springboot`, `golang-development` |

**Description.** Choose and wire Avro code generation from contracts/events for Kotlin (Gradle plugin) and Go, and OpenAPI client generation for apps.

**Acceptance criteria**

- Kotlin build generates classes from ../../contracts/events
- Go generation runs via go generate
- Generated code is never committed
- Docker builds use --build-context contracts

**Test requirements**

- build of product-service and inventory-service with one sample schema

**Definition of Done** — general DoD, plus:

- Decision recorded (ADR or contracts README)

### CF-021

**Per-component build and test scripts**

| Field | Value |
|---|---|
| Task ID | CF-021 |
| Status | ✅ Done — all 10 components built and tested via the scripts on 2026-11-12 (not yet committed) |
| Epic / feature | CF-EPIC-01 / F-02 Per-component builds and scaffolds |
| Owning service or application | `scripts` |
| Priority | P0 |
| Dependencies | [CF-030](TASKS.md#cf-030) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd` |

**Description.** build-service, test-service, build-all, test-all and affected-components scripts; each component builds with its own tooling.

**Acceptance criteria**

- Building one component never builds another
- Failures in one component do not stop *-all scripts

**Test requirements**

- scripts executed for all 10 components

**Definition of Done** — general DoD, plus:

- Documented in docs/service-catalog.md

### CF-030

**Modular monorepo layout and root guides**

| Field | Value |
|---|---|
| Task ID | CF-030 |
| Status | ✅ Done — commit 2eabbd6; no nested .git verified 2026-11-12 |
| Epic / feature | CF-EPIC-01 / F-01 Repository and architecture baseline |
| Owning service or application | `repository` |
| Priority | P0 |
| Dependencies | — |
| Required agent | `commerce-architect` |
| Required skills | `microservice-design` |

**Description.** One Git repository with services/, apps/, contracts/, infrastructure/, tests/, docs/ and root CLAUDE.md/README.

**Acceptance criteria**

- Exactly one .git at the root
- Root CLAUDE.md states independence rules

**Test requirements**

- none (structure)

**Definition of Done** — general DoD, plus:

- ADR-0004 accepted

### CF-031

**Architecture documentation set**

| Field | Value |
|---|---|
| Task ID | CF-031 |
| Status | ✅ Done — 22/22 diagrams rendered with Mermaid 10.9.1; doc validator passed (not yet committed) |
| Epic / feature | CF-EPIC-01 / F-01 Repository and architecture baseline |
| Owning service or application | `docs` |
| Priority | P0 |
| Dependencies | [CF-030](TASKS.md#cf-030) |
| Required agent | `commerce-architect` |
| Required skills | `architecture-decision-records` |

**Description.** System, data, event, API and quality architecture documents with Mermaid diagrams and ADRs 0005-0011.

**Acceptance criteria**

- All documents carry Implemented/Planned/Open status
- 22 Mermaid diagrams render
- No invented performance targets

**Test requirements**

- doc validator
- Mermaid parse+render

**Definition of Done** — general DoD, plus:

- Links resolve

### CF-032

**Buildable scaffolds for 8 services and 2 apps**

| Field | Value |
|---|---|
| Task ID | CF-032 |
| Status | ✅ Done — 5x Kotlin build + 3/3 ArchUnit + 2/2 IT; 3x Go vet/test/IT; 2x web build + 1/1 test; 10/10 images (not yet committed) |
| Epic / feature | CF-EPIC-01 / F-02 Per-component builds and scaffolds |
| Owning service or application | `services/*, apps/*` |
| Priority | P0 |
| Dependencies | [CF-021](TASKS.md#cf-021) |
| Required agent | `devops-engineer` |
| Required skills | `kotlin-springboot`, `golang-development`, `react-typescript`, `docker-kubernetes` |

**Description.** Spring Boot/Go/React scaffolds with health and readiness, migration baselines, tests and Dockerfiles.

**Acceptance criteria**

- Each component builds and tests from its folder
- Each produces its own image
- No shared runtime library

**Test requirements**

- unit + Testcontainers integration (services)
- Vitest (apps)

**Definition of Done** — general DoD, plus:

- Images built

## Phase 2 — Claude Code framework

### CF-033

**Claude Code agent team**

| Field | Value |
|---|---|
| Task ID | CF-033 |
| Status | ✅ Done — commit f32d821; validator passed |
| Epic / feature | CF-EPIC-02 / F-04 Agent team, skills and workflows |
| Owning service or application | `.claude/agents` |
| Priority | P0 |
| Dependencies | [CF-030](TASKS.md#cf-030) |
| Required agent | `commerce-architect` |
| Required skills | `code-review` |

**Description.** Ten least-privilege agents with ownership, workflow and DoD.

**Acceptance criteria**

- Frontmatter valid
- Reviewers have no write tools

**Test requirements**

- agent validator

**Definition of Done** — general DoD, plus:

- Catalogued in docs/agent-catalog.md

### CF-034

**Engineering skills library and workflows**

| Field | Value |
|---|---|
| Task ID | CF-034 |
| Status | ✅ Done — commits e377ee9, d2a656a; validator passed |
| Epic / feature | CF-EPIC-02 / F-04 Agent team, skills and workflows |
| Owning service or application | `.claude/skills` |
| Priority | P0 |
| Dependencies | [CF-033](TASKS.md#cf-033) |
| Required agent | `commerce-architect` |
| Required skills | `architecture-decision-records` |

**Description.** 31 knowledge skills and 12 workflow skills.

**Acceptance criteria**

- 12 sections per knowledge skill
- 10 sections per workflow

**Test requirements**

- skill validator

**Definition of Done** — general DoD, plus:

- Catalogued

### CF-035

**Guardrail hooks with tests**

| Field | Value |
|---|---|
| Task ID | CF-035 |
| Status | ✅ Done — 85/85 hook tests on 2026-11-12 |
| Epic / feature | CF-EPIC-02 / F-05 Guardrail hooks |
| Owning service or application | `.claude/hooks` |
| Priority | P0 |
| Dependencies | [CF-034](TASKS.md#cf-034) |
| Required agent | `devops-engineer` |
| Required skills | `security-review` |

**Description.** Destructive-command guard, secret detection, formatting, architecture-docs and test-reminder hooks.

**Acceptance criteria**

- Hook suite passes
- No false positives on repository files

**Test requirements**

- Test-Hooks.ps1

**Definition of Done** — general DoD, plus:

- Documented in docs/hook-catalog.md

### CF-036

**Observe hooks in a live Claude session**

| Field | Value |
|---|---|
| Task ID | CF-036 |
| Status | 🟡 In progress — detect-secrets ran on a real commit; Stop hooks (remind-tests, architecture-docs A1) fired live and were satisfied; deny/ask not yet observed live |
| Epic / feature | CF-EPIC-02 / F-05 Guardrail hooks |
| Owning service or application | `.claude/hooks` |
| Priority | P3 |
| Dependencies | [CF-035](TASKS.md#cf-035) |
| Required agent | `test-engineer` |
| Required skills | `code-review` |

**Description.** Confirm each hook fires through Claude Code (not only via recorded payloads).

**Acceptance criteria**

- A denied command, a secret write and a Stop reminder observed in a session transcript

**Test requirements**

- manual session check

**Definition of Done** — general DoD, plus:

- Result added to docs/hook-catalog.md

## Phase 3 — Local infrastructure

### CF-005

**Local Compose infrastructure stack**

| Field | Value |
|---|---|
| Task ID | CF-005 |
| Status | ✅ Done — up.ps1 + health.ps1 all checks passed 2026-11-12; verification log in infrastructure/README.md |
| Epic / feature | CF-EPIC-03 / F-06 Local Compose stack |
| Owning service or application | `infrastructure` |
| Priority | P0 |
| Dependencies | [CF-032](TASKS.md#cf-032) |
| Required agent | `devops-engineer` |
| Required skills | `docker-kubernetes`, `observability` |

**Description.** PostgreSQL (8 databases, per-service roles), Kafka, Connect/Debezium, Schema Registry, Kafka UI, Redis, OTel, Prometheus, Grafana, Loki, Tempo.

**Acceptance criteria**

- up.ps1 brings every container to healthy
- health.ps1 passes
- No credentials in files except local .env.example

**Test requirements**

- infrastructure/scripts/health.ps1

**Definition of Done** — general DoD, plus:

- Verification log in infrastructure/README.md filled

### CF-037

**Verify CDC end to end locally**

| Field | Value |
|---|---|
| Task ID | CF-037 |
| Status | ✅ Done — verify-cdc.ps1 passed 2026-11-12 after switching to BinaryDataConverter (ADR-0007) |
| Epic / feature | CF-EPIC-03 / F-07 Local CDC pipeline |
| Owning service or application | `infrastructure` |
| Priority | P0 |
| Dependencies | [CF-005](TASKS.md#cf-005) |
| Required agent | `event-driven-engineer` |
| Required skills | `debezium-cdc`, `transactional-outbox` |

**Description.** Run migrate, register-connectors and verify-cdc for product-service.

**Acceptance criteria**

- verify-cdc.ps1 passes: key, id/eventType/traceparent headers and payload bytes match the outbox row

**Test requirements**

- verify-cdc.ps1

**Definition of Done** — general DoD, plus:

- Result recorded in infrastructure/README.md verification log

### CF-038

**Wire application services and Toxiproxy into Compose**

| Field | Value |
|---|---|
| Task ID | CF-038 |
| Status | 🟡 In progress — product-service and inventory-service in the `apps` profile, healthy; 8 components and Toxiproxy remain |
| Epic / feature | CF-EPIC-03 / F-06 Local Compose stack |
| Owning service or application | `infrastructure` |
| Priority | P1 |
| Dependencies | [CF-005](TASKS.md#cf-005), [CF-032](TASKS.md#cf-032) |
| Required agent | `devops-engineer` |
| Required skills | `docker-kubernetes`, `resilience-testing` |

**Description.** Add the 10 images to Compose (profile `apps`) with env-based config and readiness-based dependencies; add Toxiproxy in front of PostgreSQL/Kafka for resilience tests.

**Acceptance criteria**

- `docker compose --profile apps up` starts all services healthy
- Each service connects with its own DB role

**Test requirements**

- health.ps1 extended to services

**Definition of Done** — general DoD, plus:

- README updated

### CF-039

**Expose Kafka Connect/Debezium metrics**

| Field | Value |
|---|---|
| Task ID | CF-039 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-12 / F-20 Operability of the event pipeline |
| Owning service or application | `infrastructure` |
| Priority | P2 |
| Dependencies | [CF-005](TASKS.md#cf-005) |
| Required agent | `devops-engineer` |
| Required skills | `observability`, `debezium-cdc` |

**Description.** JMX exporter for Connect; dashboard panels for connector state and streaming lag.

**Acceptance criteria**

- Prometheus scrapes Connect metrics
- Dashboard shows connector state

**Test requirements**

- Prometheus target up

**Definition of Done** — general DoD, plus:

- Dashboard committed

## Phase 4 — Product Service and CDC

### CF-002

**v1 Avro schemas for the core event catalogue**

| Field | Value |
|---|---|
| Task ID | CF-002 |
| Status | 🟡 In progress — EventMetadata.v1 + ProductCreated.v1 written and registered (id 1, BACKWARD); 13 events + 4 commands remain |
| Epic / feature | CF-EPIC-12 / F-19 Contracts and compatibility |
| Owning service or application | `contracts/events` |
| Priority | P0 |
| Dependencies | [CF-031](TASKS.md#cf-031) |
| Required agent | `event-driven-engineer` |
| Required skills | `schema-evolution`, `kafka-event-driven` |

**Description.** EventMetadata, Money and the 14 core events plus 4 saga commands as .avsc files.

**Acceptance criteria**

- Schemas match docs/event-catalog/event-catalog.md
- Every schema parses
- Enums have UNKNOWN default

**Test requirements**

- Avro parse of every file

**Definition of Done** — general DoD, plus:

- Catalogue and schemas updated in one commit (hook A1)

### CF-040

**Shared contract compatibility testing**

| Field | Value |
|---|---|
| Task ID | CF-040 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-12 / F-19 Contracts and compatibility |
| Owning service or application | `tests/contract` |
| Priority | P0 |
| Dependencies | [CF-002](TASKS.md#cf-002), [CF-005](TASKS.md#cf-005) |
| Required agent | `test-engineer` |
| Required skills | `contract-testing`, `schema-evolution` |

**Description.** Script and CI job that registers schemas in a local registry and checks BACKWARD compatibility of changed subjects; runs for every consumer and producer affected.

**Acceptance criteria**

- Changing a field incompatibly fails the check
- Additive change passes
- Job triggered by any contracts/events change

**Test requirements**

- positive and negative compatibility fixtures

**Definition of Done** — general DoD, plus:

- Documented in tests/contract/README.md

### CF-043

**product-service: Product aggregate and catalog API**

| Field | Value |
|---|---|
| Task ID | CF-043 |
| Status | ✅ Done — POST/GET /v1/products; spec lint valid; 23 unit tests + ProductApiIT 6/6 (Testcontainers) 2026-11-12; code review approve-with-comments, fixes retested |
| Epic / feature | CF-EPIC-04 / F-08 Product catalog API |
| Owning service or application | `services/product-service` |
| Priority | P0 |
| Dependencies | [CF-032](TASKS.md#cf-032) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `create-api`, `domain-driven-design`, `rest-api-design`, `database-migrations` |

**Description.** OpenAPI spec, Product/SKU aggregate with lifecycle, POST/GET /v1/products, Flyway tables, problem details.

**Acceptance criteria**

- Spec linted
- Create and read product work against PostgreSQL
- Invariants unit-tested

**Test requirements**

- domain unit tests
- repository and API integration tests (Testcontainers)

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-044

**product-service: ProductCreated through the outbox**

| Field | Value |
|---|---|
| Task ID | CF-044 |
| Status | ✅ Done — needed only the ProductCreated slices of CF-002/CF-003 (dependency narrowed 2026-11-12); OutboxAtomicityIT 3/3; writer schema pinned to the generated class (registry id 1), use.latest.version=false; retested 2026-11-12 |
| Epic / feature | CF-EPIC-04 / F-09 Product events via CDC (vertical slice) |
| Owning service or application | `services/product-service` |
| Priority | P0 |
| Dependencies | [CF-043](TASKS.md#cf-043) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `transactional-outbox`, `schema-evolution` |

**Description.** Map domain event to Avro, serialize with registered schema, write outbox row in the same transaction.

**Acceptance criteria**

- Commit writes exactly one outbox row with topic cf.product.events.v1 and key productId
- Rollback writes none

**Test requirements**

- outbox atomicity integration test

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-045

**Vertical slice: product created reaches Kafka via Debezium**

| Field | Value |
|---|---|
| Task ID | CF-045 |
| Status | ✅ Done — needed only the product/inventory part of CF-038 (dependency narrowed 2026-11-12); tests/integration/run-e2e.ps1 PASS 2026-11-12: key, headers, Avro envelope (schema id 1), correlation id, one Tempo trace across both services; not yet in CI (needs CF-020) |
| Epic / feature | CF-EPIC-04 / F-09 Product events via CDC (vertical slice) |
| Owning service or application | `tests/integration` |
| Priority | P0 |
| Dependencies | [CF-044](TASKS.md#cf-044), [CF-037](TASKS.md#cf-037) |
| Required agent | `test-engineer` |
| Required skills | `playwright-e2e`, `debezium-cdc`, `distributed-tracing` |

**Description.** Create a product through the API on the Compose stack and observe ProductCreated on cf.product.events.v1 with headers and decodable Avro.

**Acceptance criteria**

- Record key = productId
- Payload decodes with the registered schema
- traceparent header present

**Test requirements**

- tests/integration product-cdc test

**Definition of Done** — general DoD, plus:

- Runs in CI nightly

## Phase 5 — Inventory and Customer

### CF-046

**inventory-service: consume ProductCreated with inbox and DLT**

| Field | Value |
|---|---|
| Task ID | CF-046 |
| Status | ✅ Done — inventory consumer: unit + Testcontainers (processing, duplicates, poison -> DLT, permanent data errors -> DLT, transient retries, restart from committed offsets) pass 2026-11-12 |
| Epic / feature | CF-EPIC-06 / F-11 Stock projection and adjustments |
| Owning service or application | `services/inventory-service` |
| Priority | P0 |
| Dependencies | [CF-045](TASKS.md#cf-045) |
| Required agent | `golang-backend-engineer` |
| Required skills | `idempotent-consumer`, `retry-and-dead-letter-queue`, `kafka-event-driven` |

**Description.** Kafka consumer (franz-go), inbox dedupe, bounded retries, DLT, stock_item projection.

**Acceptance criteria**

- Duplicate delivery creates one stock item
- Poison message lands in DLT
- Offsets committed after DB commit

**Test requirements**

- duplicate, poison and crash-before-ack tests (Testcontainers Kafka + PostgreSQL)

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-048

**inventory-service: ReserveInventory / ReleaseInventory handlers**

| Field | Value |
|---|---|
| Task ID | CF-048 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-06 / F-12 Reservations for the saga |
| Owning service or application | `services/inventory-service` |
| Priority | P0 |
| Dependencies | [CF-046](TASKS.md#cf-046), [CF-002](TASKS.md#cf-002) |
| Required agent | `golang-backend-engineer` |
| Required skills | `saga-pattern`, `transaction-management`, `idempotent-consumer` |

**Description.** Atomic reservation, StockReserved/StockReservationFailed/StockReleased replies, idempotent release.

**Acceptance criteria**

- No oversell under concurrent reservations
- Release replies even when nothing was reserved

**Test requirements**

- concurrency test on last unit
- duplicate command test

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-052

**pricing-service: prices with ETag and ProductPriceChanged**

| Field | Value |
|---|---|
| Task ID | CF-052 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-07 / F-13 Prices and quotes |
| Owning service or application | `services/pricing-service` |
| Priority | P0 |
| Dependencies | [CF-045](TASKS.md#cf-045) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `create-api`, `idempotent-consumer`, `transactional-outbox` |

**Description.** Consume ProductCreated, manage prices (PUT with If-Match), publish ProductPriceChanged.

**Acceptance criteria**

- 412 on stale ETag
- One ProductPriceChanged per committed change

**Test requirements**

- consumer and API integration tests

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-047

**inventory-service: stock adjustment API**

| Field | Value |
|---|---|
| Task ID | CF-047 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-06 / F-11 Stock projection and adjustments |
| Owning service or application | `services/inventory-service` |
| Priority | P1 |
| Dependencies | [CF-046](TASKS.md#cf-046) |
| Required agent | `golang-backend-engineer` |
| Required skills | `create-api`, `transaction-management` |

**Description.** Admin endpoint to adjust on-hand stock with ETag; StockLevelChanged event.

**Acceptance criteria**

- Concurrent adjustments do not lose updates
- StockLevelChanged emitted via outbox

**Test requirements**

- concurrency test

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-050

**customer-service: profile and address API**

| Field | Value |
|---|---|
| Task ID | CF-050 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-05 / F-10 Customer profile |
| Owning service or application | `services/customer-service` |
| Priority | P1 |
| Dependencies | [CF-032](TASKS.md#cf-032) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `create-api`, `secure-backend-development` |

**Description.** Customer profile and addresses with object-level authorization.

**Acceptance criteria**

- Customer reads and edits only own profile

**Test requirements**

- API integration tests
- authZ negative tests

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-051

**customer-service: CustomerRegistered / CustomerContactChanged**

| Field | Value |
|---|---|
| Task ID | CF-051 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-05 / F-10 Customer profile |
| Owning service or application | `services/customer-service` |
| Priority | P1 |
| Dependencies | [CF-050](TASKS.md#cf-050), [CF-002](TASKS.md#cf-002) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `transactional-outbox`, `create-domain-event` |

**Description.** Publish customer facts via outbox; minimal personal data in events.

**Acceptance criteria**

- Events contain only fields notification needs

**Test requirements**

- outbox integration test

**Definition of Done** — general DoD, plus:

- security-audit on PII fields

### CF-094

**Outbox and inbox retention jobs**

| Field | Value |
|---|---|
| Task ID | CF-094 |
| Status | ⬜ Not started — raised by the Prompt 09 code review (2026-11-12) |
| Epic / feature | CF-EPIC-06 / F-11 Stock projection and adjustments |
| Owning service or application | `services/*` |
| Priority | P1 |
| Dependencies | [CF-044](TASKS.md#cf-044), [CF-046](TASKS.md#cf-046) |
| Required agent | `database-engineer` |
| Required skills | `transactional-outbox`, `idempotent-consumer`, `database-migrations` |

**Description.** Delete published outbox rows and old inbox rows in batches (per service, own database) after a retention window agreed with ops; outbox rows are only needed until Debezium has read them.

**Acceptance criteria**

- Outbox/inbox tables stay bounded under load
- Deletion runs in small batches without long locks
- Inbox retention exceeds the maximum redelivery window

**Test requirements**

- retention job integration test

**Definition of Done** — general DoD, plus:

- Retention documented in the service README

## Phase 6 — Order and Payment

### CF-053

**pricing-service: price quote API**

| Field | Value |
|---|---|
| Task ID | CF-053 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-07 / F-13 Prices and quotes |
| Owning service or application | `services/pricing-service` |
| Priority | P0 |
| Dependencies | [CF-052](TASKS.md#cf-052) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `create-api` |

**Description.** POST /v1/quotes returns a quote with expiry for SKUs and quantities.

**Acceptance criteria**

- Quote is stored and referenced by id
- Expired quotes are rejected

**Test requirements**

- API tests
- Pact provider verification for order-service

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-055

**order-service: create order (202, idempotency key) and OrderCreated**

| Field | Value |
|---|---|
| Task ID | CF-055 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-08 / F-14 Order creation and history |
| Owning service or application | `services/order-service` |
| Priority | P0 |
| Dependencies | [CF-053](TASKS.md#cf-053), [CF-050](TASKS.md#cf-050) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `create-api`, `saga-pattern`, `transactional-outbox` |

**Description.** POST /v1/orders validates quote and customer, persists PENDING order and saga instance, writes OrderCreated + ReserveInventory to the outbox.

**Acceptance criteria**

- Retry with same Idempotency-Key returns the same order
- One transaction writes order, saga and outbox rows

**Test requirements**

- API + outbox integration tests
- Pact consumer tests against pricing and customer

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-057

**payment-service: AuthorizePayment / VoidPayment with provider adapter**

| Field | Value |
|---|---|
| Task ID | CF-057 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-09 / F-16 Payment authorization and compensation |
| Owning service or application | `services/payment-service` |
| Priority | P0 |
| Dependencies | [CF-002](TASKS.md#cf-002), [CF-032](TASKS.md#cf-032) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `saga-pattern`, `domain-driven-design`, `secure-backend-development` |

**Description.** Anti-corruption adapter (stub until CF-016), idempotency keys toward the provider, PaymentAuthorized/Failed/Voided replies.

**Acceptance criteria**

- Duplicate command authorizes once
- Void replies even when nothing was authorized

**Test requirements**

- handler integration tests with provider stub
- duplicate command test

**Definition of Done** — general DoD, plus:

- security-audit approve

### CF-014

**Decide cart ownership**

| Field | Value |
|---|---|
| Task ID | CF-014 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-08 / F-14 Order creation and history |
| Owning service or application | `docs` |
| Priority | P1 |
| Dependencies | [CF-001](TASKS.md#cf-001) |
| Required agent | `commerce-architect` |
| Required skills | `microservice-design`, `architecture-decision-records` |

**Description.** order-service vs dedicated context vs client-side cart.

**Acceptance criteria**

- ADR accepted

**Test requirements**

- none (decision)

**Definition of Done** — general DoD, plus:

- ADR accepted

### CF-016

**Choose payment provider and sandbox; decide capture timing**

| Field | Value |
|---|---|
| Task ID | CF-016 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-09 / F-16 Payment authorization and compensation |
| Owning service or application | `services/payment-service` |
| Priority | P1 |
| Dependencies | [CF-001](TASKS.md#cf-001) |
| Required agent | `commerce-architect` |
| Required skills | `architecture-decision-records`, `security-review` |

**Description.** Provider selection, sandbox access and capture policy (CF-028 merged).

**Acceptance criteria**

- ADR accepted
- Card data never touches CommerceFlow

**Test requirements**

- none (decision)

**Definition of Done** — general DoD, plus:

- ADR accepted

### CF-056

**order-service: order history read model and GET APIs**

| Field | Value |
|---|---|
| Task ID | CF-056 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-08 / F-14 Order creation and history |
| Owning service or application | `services/order-service` |
| Priority | P1 |
| Dependencies | [CF-055](TASKS.md#cf-055) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `create-api`, `postgresql-design` |

**Description.** Customer and admin order queries with cursor pagination.

**Acceptance criteria**

- Keyset pagination
- Customers see only own orders

**Test requirements**

- API and authZ tests

**Definition of Done** — general DoD, plus:

- code-review approve

## Phase 7 — Saga and asynchronous workflows

### CF-010

**Order saga happy path end to end**

| Field | Value |
|---|---|
| Task ID | CF-010 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-08 / F-15 Order saga |
| Owning service or application | `services/order-service + inventory + payment` |
| Priority | P0 |
| Dependencies | [CF-055](TASKS.md#cf-055), [CF-048](TASKS.md#cf-048), [CF-057](TASKS.md#cf-057), [CF-038](TASKS.md#cf-038) |
| Required agent | `commerce-architect` |
| Required skills | `implement-feature`, `saga-pattern` |

**Description.** Order reaches CONFIRMED through StockReserved and PaymentAuthorized on the Compose stack.

**Acceptance criteria**

- Order CONFIRMED with one reservation and one authorization
- One trace spans order, inventory and payment

**Test requirements**

- tests/integration saga happy path

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-011

**Saga compensation and timeouts**

| Field | Value |
|---|---|
| Task ID | CF-011 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-08 / F-15 Order saga |
| Owning service or application | `services/order-service + inventory + payment` |
| Priority | P0 |
| Dependencies | [CF-010](TASKS.md#cf-010) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `saga-pattern`, `resilience-testing` |

**Description.** Failure and timeout transitions, VoidPayment/ReleaseInventory, late replies ignored.

**Acceptance criteria**

- Every path in communication-patterns.md state machine reaches a terminal state

**Test requirements**

- Toxiproxy scenarios R3, R4, R6
- transition-table unit tests

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-023

**Runbooks: slot growth, DLT replay, stuck saga, registry rejects schema**

| Field | Value |
|---|---|
| Task ID | CF-023 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-12 / F-20 Operability of the event pipeline |
| Owning service or application | `docs/runbooks` |
| Priority | P1 |
| Dependencies | [CF-042](TASKS.md#cf-042), [CF-059](TASKS.md#cf-059) |
| Required agent | `devops-engineer` |
| Required skills | `debug-event-flow`, `observability` |

**Description.** Operational procedures linked from alerts.

**Acceptance criteria**

- Each alert links a runbook

**Test requirements**

- dry run of each runbook locally

**Definition of Done** — general DoD, plus:

- Reviewed by event-driven-engineer

### CF-042

**DLT replay tool**

| Field | Value |
|---|---|
| Task ID | CF-042 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-12 / F-20 Operability of the event pipeline |
| Owning service or application | `scripts` |
| Priority | P1 |
| Dependencies | [CF-046](TASKS.md#cf-046) |
| Required agent | `event-driven-engineer` |
| Required skills | `retry-and-dead-letter-queue` |

**Description.** Read DLT, re-publish to original topic with same key and id header, record progress; user-approved operation.

**Acceptance criteria**

- Replayed message processed once (inbox)

**Test requirements**

- replay integration test

**Definition of Done** — general DoD, plus:

- Runbook written

### CF-049

**inventory-service: commit reservation on OrderConfirmed and expiry**

| Field | Value |
|---|---|
| Task ID | CF-049 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-06 / F-12 Reservations for the saga |
| Owning service or application | `services/inventory-service` |
| Priority | P1 |
| Dependencies | [CF-048](TASKS.md#cf-048), [CF-010](TASKS.md#cf-010) |
| Required agent | `golang-backend-engineer` |
| Required skills | `saga-pattern`, `transaction-management` |

**Description.** Committed reservations never expire; unconfirmed ones expire and release.

**Acceptance criteria**

- Confirmed order stock never released by expiry

**Test requirements**

- expiry job test

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-059

**Stuck-saga metric and saga status endpoint**

| Field | Value |
|---|---|
| Task ID | CF-059 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-08 / F-15 Order saga |
| Owning service or application | `services/order-service` |
| Priority | P1 |
| Dependencies | [CF-010](TASKS.md#cf-010) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `observability`, `create-api` |

**Description.** commerceflow_sagas_past_deadline metric and an admin read endpoint for saga state.

**Acceptance criteria**

- Metric exposed
- Endpoint authorized for ROLE_ORDER_ADMIN

**Test requirements**

- metric unit test
- API test

**Definition of Done** — general DoD, plus:

- Alert rule drafted

### CF-060

**shipping-service: shipment from OrderConfirmed**

| Field | Value |
|---|---|
| Task ID | CF-060 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-10 / F-17 Shipments |
| Owning service or application | `services/shipping-service` |
| Priority | P1 |
| Dependencies | [CF-010](TASKS.md#cf-010) |
| Required agent | `golang-backend-engineer` |
| Required skills | `idempotent-consumer`, `transactional-outbox` |

**Description.** Consume OrderConfirmed, create shipment, publish ShipmentCreated.

**Acceptance criteria**

- One shipment per order

**Test requirements**

- consumer integration test

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-062

**Cancel a confirmed order (OrderCancelled flow)**

| Field | Value |
|---|---|
| Task ID | CF-062 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-08 / F-15 Order saga |
| Owning service or application | `order + inventory + payment + shipping` |
| Priority | P1 |
| Dependencies | [CF-010](TASKS.md#cf-010), [CF-060](TASKS.md#cf-060) |
| Required agent | `commerce-architect` |
| Required skills | `implement-feature`, `saga-pattern` |

**Description.** Cancellation API, OrderCancelled consumers: release stock, refund, stop shipment.

**Acceptance criteria**

- Refund once per order
- Shipment stopped if not dispatched

**Test requirements**

- tests/integration cancellation flow

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-063

**notification-service: email notifications for order lifecycle**

| Field | Value |
|---|---|
| Task ID | CF-063 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-11 / F-18 Notifications |
| Owning service or application | `services/notification-service` |
| Priority | P1 |
| Dependencies | [CF-010](TASKS.md#cf-010), [CF-051](TASKS.md#cf-051) |
| Required agent | `golang-backend-engineer` |
| Required skills | `idempotent-consumer`, `retry-and-dead-letter-queue` |

**Description.** Consumers for order/payment/shipment events, templates, delivery via a local SMTP catcher.

**Acceptance criteria**

- One email per event and channel
- Non-blocking retries; ordering not required

**Test requirements**

- consumer integration tests

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-061

**shipping-service: carrier adapter stub and tracking events**

| Field | Value |
|---|---|
| Task ID | CF-061 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-10 / F-17 Shipments |
| Owning service or application | `services/shipping-service` |
| Priority | P2 |
| Dependencies | [CF-060](TASKS.md#cf-060) |
| Required agent | `golang-backend-engineer` |
| Required skills | `domain-driven-design`, `secure-backend-development` |

**Description.** Carrier ACL (stub), ShipmentDispatched/ShipmentDelivered with webhook dedupe.

**Acceptance criteria**

- Duplicate webhook publishes once

**Test requirements**

- webhook tests

**Definition of Done** — general DoD, plus:

- security-audit approve

## Phase 8 — Admin Dashboard

### CF-024

**API gateway and admin BFF**

| Field | Value |
|---|---|
| Task ID | CF-024 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-13 / F-21 Admin access and management screens |
| Owning service or application | `apps/admin-web, infrastructure` |
| Priority | P0 |
| Dependencies | [CF-065](TASKS.md#cf-065), [CF-001](TASKS.md#cf-001) |
| Required agent | `frontend-engineer` |
| Required skills | `admin-dashboard-development`, `secure-backend-development` |

**Description.** Gateway routing, rate and size limits, CORS; admin BFF with token handler and read composition via service APIs only.

**Acceptance criteria**

- BFF has no business database
- Admin browser holds no tokens

**Test requirements**

- BFF integration tests
- gateway routing tests

**Definition of Done** — general DoD, plus:

- security-audit approve

### CF-065

**Local identity provider (Keycloak) and roles**

| Field | Value |
|---|---|
| Task ID | CF-065 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-17 / F-26 Identity and authorization |
| Owning service or application | `infrastructure` |
| Priority | P0 |
| Dependencies | [CF-005](TASKS.md#cf-005) |
| Required agent | `devops-engineer` |
| Required skills | `secure-backend-development` |

**Description.** Keycloak in Compose with realm, clients (storefront PKCE, admin BFF, service clients) and roles from authentication-authorization.md.

**Acceptance criteria**

- Tokens carry correct issuer, audience and roles
- No credentials committed

**Test requirements**

- token issuance smoke test

**Definition of Done** — general DoD, plus:

- security-audit approve

### CF-068

**JWT resource server in every service**

| Field | Value |
|---|---|
| Task ID | CF-068 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-17 / F-26 Identity and authorization |
| Owning service or application | `services/*` |
| Priority | P0 |
| Dependencies | [CF-065](TASKS.md#cf-065) |
| Required agent | `kotlin-backend-engineer` |
| Required skills | `secure-backend-development`, `security-audit` |

**Description.** Issuer, audience and algorithm validation; function- and object-level authorization.

**Acceptance criteria**

- 401/403/404 negative tests pass for every protected endpoint

**Test requirements**

- security slice tests per service

**Definition of Done** — general DoD, plus:

- security-audit approve

### CF-064

**admin-web: login and role-gated routes**

| Field | Value |
|---|---|
| Task ID | CF-064 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-13 / F-21 Admin access and management screens |
| Owning service or application | `apps/admin-web` |
| Priority | P1 |
| Dependencies | [CF-024](TASKS.md#cf-024) |
| Required agent | `frontend-engineer` |
| Required skills | `admin-dashboard-development`, `react-typescript` |

**Description.** Login via BFF, session handling, RequireRole routes.

**Acceptance criteria**

- Routes redirect without role

**Test requirements**

- component tests
- Playwright login test

**Definition of Done** — general DoD, plus:

- a11y checks

### CF-066

**admin-web: catalog and price management**

| Field | Value |
|---|---|
| Task ID | CF-066 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-13 / F-21 Admin access and management screens |
| Owning service or application | `apps/admin-web` |
| Priority | P1 |
| Dependencies | [CF-064](TASKS.md#cf-064), [CF-043](TASKS.md#cf-043), [CF-052](TASKS.md#cf-052) |
| Required agent | `frontend-engineer` |
| Required skills | `admin-dashboard-development`, `contract-testing` |

**Description.** Paginated product list, product edit, price edit with ETag conflict handling.

**Acceptance criteria**

- 412 shows conflict dialog

**Test requirements**

- component tests
- Pact consumer tests

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-067

**admin-web: orders and saga status**

| Field | Value |
|---|---|
| Task ID | CF-067 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-13 / F-21 Admin access and management screens |
| Owning service or application | `apps/admin-web` |
| Priority | P2 |
| Dependencies | [CF-064](TASKS.md#cf-064), [CF-059](TASKS.md#cf-059) |
| Required agent | `frontend-engineer` |
| Required skills | `admin-dashboard-development` |

**Description.** Order list, order detail with saga state, cancellation with confirmation.

**Acceptance criteria**

- Destructive action confirmed

**Test requirements**

- component tests
- Pact consumer tests

**Definition of Done** — general DoD, plus:

- code-review approve

## Phase 9 — Storefront

### CF-074

**storefront-web: checkout and order status**

| Field | Value |
|---|---|
| Task ID | CF-074 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-14 / F-23 Checkout and order tracking |
| Owning service or application | `apps/storefront-web` |
| Priority | P0 |
| Dependencies | [CF-055](TASKS.md#cf-055), [CF-065](TASKS.md#cf-065), [CF-014](TASKS.md#cf-014) |
| Required agent | `frontend-engineer` |
| Required skills | `react-typescript`, `playwright-e2e` |

**Description.** Checkout with idempotency key reuse on retry, 202 handling and status polling.

**Acceptance criteria**

- Double click creates one order

**Test requirements**

- component tests
- Playwright checkout journey

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-015

**Decide catalog read model ownership**

| Field | Value |
|---|---|
| Task ID | CF-015 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-14 / F-22 Catalog browsing |
| Owning service or application | `docs` |
| Priority | P1 |
| Dependencies | [CF-001](TASKS.md#cf-001) |
| Required agent | `commerce-architect` |
| Required skills | `microservice-design`, `architecture-decision-records` |

**Description.** Where the product+price+availability read model lives.

**Acceptance criteria**

- ADR accepted

**Test requirements**

- none (decision)

**Definition of Done** — general DoD, plus:

- ADR accepted

### CF-072

**Catalog read model**

| Field | Value |
|---|---|
| Task ID | CF-072 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-14 / F-22 Catalog browsing |
| Owning service or application | `per CF-015` |
| Priority | P1 |
| Dependencies | [CF-015](TASKS.md#cf-015), [CF-052](TASKS.md#cf-052), [CF-047](TASKS.md#cf-047) |
| Required agent | `golang-backend-engineer` |
| Required skills | `idempotent-consumer`, `kafka-event-driven` |

**Description.** Projection from ProductCreated/Updated, ProductPriceChanged, StockLevelChanged; rebuildable by replay.

**Acceptance criteria**

- Replay into a new group rebuilds the model

**Test requirements**

- projection and replay tests

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-073

**storefront-web: browse and product detail**

| Field | Value |
|---|---|
| Task ID | CF-073 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-14 / F-22 Catalog browsing |
| Owning service or application | `apps/storefront-web` |
| Priority | P1 |
| Dependencies | [CF-072](TASKS.md#cf-072), [CF-024](TASKS.md#cf-024) |
| Required agent | `frontend-engineer` |
| Required skills | `react-typescript`, `contract-testing` |

**Description.** Product list and detail via gateway with generated clients.

**Acceptance criteria**

- Loading/empty/error states
- Keyboard accessible

**Test requirements**

- component tests
- Pact consumer tests

**Definition of Done** — general DoD, plus:

- a11y checks

### CF-075

**storefront-web: order history**

| Field | Value |
|---|---|
| Task ID | CF-075 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-14 / F-23 Checkout and order tracking |
| Owning service or application | `apps/storefront-web` |
| Priority | P2 |
| Dependencies | [CF-056](TASKS.md#cf-056), [CF-074](TASKS.md#cf-074) |
| Required agent | `frontend-engineer` |
| Required skills | `react-typescript` |

**Description.** Paginated history of own orders.

**Acceptance criteria**

- Only own orders visible

**Test requirements**

- component tests
- Pact consumer test

**Definition of Done** — general DoD, plus:

- code-review approve

## Phase 10 — Complete testing

### CF-017

**Pact consumer/provider and broker**

| Field | Value |
|---|---|
| Task ID | CF-017 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-15 / F-24 Automated test layers |
| Owning service or application | `apps, services, tests/contract` |
| Priority | P1 |
| Dependencies | [CF-073](TASKS.md#cf-073), [CF-055](TASKS.md#cf-055) |
| Required agent | `test-engineer` |
| Required skills | `contract-testing` |

**Description.** Local Pact broker, consumer pacts from apps and order-service, provider verification, can-i-deploy.

**Acceptance criteria**

- Removing a used field fails provider verification

**Test requirements**

- provider verification jobs

**Definition of Done** — general DoD, plus:

- Documented

### CF-020

**Reusable CI workflows per language**

| Field | Value |
|---|---|
| Task ID | CF-020 |
| Status | 🟡 In progress — _kotlin-service, _go-service, _web-app + 10 callers + contracts.yml written; actionlint 1.7.7: 0 errors in 14 files (2026-11-12); Avro check passes and fails a seeded bad schema; first GitHub runs pending the owner's push |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `.github/workflows` |
| Priority | P1 |
| Dependencies | [CF-021](TASKS.md#cf-021) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd` |

**Description.** _kotlin-service, _go-service, _web-app templates; contracts workflow.

**Acceptance criteria**

- actionlint passes
- Runs green on GitHub

**Test requirements**

- actionlint
- first runs

**Definition of Done** — general DoD, plus:

- Documented

### CF-022

**Architecture tests in every service**

| Field | Value |
|---|---|
| Task ID | CF-022 |
| Status | 🟡 In progress — ArchUnit rules run in all 5 Kotlin services (3/3 each); Go import tests not written yet |
| Epic / feature | CF-EPIC-15 / F-24 Automated test layers |
| Owning service or application | `services/*` |
| Priority | P1 |
| Dependencies | [CF-032](TASKS.md#cf-032) |
| Required agent | `test-engineer` |
| Required skills | `clean-architecture` |

**Description.** Fail builds on layer violations and cross-service imports.

**Acceptance criteria**

- Kotlin ArchUnit rules
- Go import test per service

**Test requirements**

- deliberate violation fails the build

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-076

**Cross-service integration suite**

| Field | Value |
|---|---|
| Task ID | CF-076 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-15 / F-24 Automated test layers |
| Owning service or application | `tests/integration` |
| Priority | P1 |
| Dependencies | [CF-010](TASKS.md#cf-010), [CF-038](TASKS.md#cf-038) |
| Required agent | `test-engineer` |
| Required skills | `write-tests`, `testcontainers` |

**Description.** Saga, cancellation and CDC flows against Compose, bounded polling.

**Acceptance criteria**

- Suite runs from one command

**Test requirements**

- the suite itself

**Definition of Done** — general DoD, plus:

- Runs nightly

### CF-078

**Resilience scenario catalogue R1-R6**

| Field | Value |
|---|---|
| Task ID | CF-078 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-15 / F-24 Automated test layers |
| Owning service or application | `tests/resilience` |
| Priority | P1 |
| Dependencies | [CF-011](TASKS.md#cf-011), [CF-038](TASKS.md#cf-038) |
| Required agent | `test-engineer` |
| Required skills | `resilience-testing` |

**Description.** Toxiproxy scenarios with expected outcomes.

**Acceptance criteria**

- Each scenario asserts consistency after recovery

**Test requirements**

- the scenarios

**Definition of Done** — general DoD, plus:

- Nightly

### CF-018

**k6 baselines for browse and checkout**

| Field | Value |
|---|---|
| Task ID | CF-018 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-15 / F-24 Automated test layers |
| Owning service or application | `tests/performance` |
| Priority | P2 |
| Dependencies | [CF-010](TASKS.md#cf-010), [CF-073](TASKS.md#cf-073) |
| Required agent | `test-engineer` |
| Required skills | `performance-testing` |

**Description.** Measure baselines (no thresholds until CF-025).

**Acceptance criteria**

- Baseline recorded with environment description

**Test requirements**

- k6 runs

**Definition of Done** — general DoD, plus:

- Results in tests/performance/README.md

### CF-077

**Cross-app Playwright journeys**

| Field | Value |
|---|---|
| Task ID | CF-077 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-15 / F-24 Automated test layers |
| Owning service or application | `tests/e2e` |
| Priority | P2 |
| Dependencies | [CF-066](TASKS.md#cf-066), [CF-074](TASKS.md#cf-074) |
| Required agent | `test-engineer` |
| Required skills | `playwright-e2e`, `run-e2e` |

**Description.** Admin creates product and price, customer buys it, order confirmed.

**Acceptance criteria**

- Journey passes headless with traces

**Test requirements**

- the journey

**Definition of Done** — general DoD, plus:

- Report via run-e2e

## Phase 11 — Observability and security

### CF-012

**OpenTelemetry in all services, trace through outbox**

| Field | Value |
|---|---|
| Task ID | CF-012 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-16 / F-25 Telemetry and SLOs |
| Owning service or application | `services/*` |
| Priority | P1 |
| Dependencies | [CF-045](TASKS.md#cf-045) |
| Required agent | `devops-engineer` |
| Required skills | `distributed-tracing`, `observability` |

**Description.** Java agent / Go SDK, traceparent into outbox and out of Kafka headers, trace ids in logs.

**Acceptance criteria**

- One trace for a placed order across services in Tempo

**Test requirements**

- tracing unit test (in-memory exporter)
- Tempo query in integration test

**Definition of Done** — general DoD, plus:

- Dashboard links work

### CF-025

**Define SLOs**

| Field | Value |
|---|---|
| Task ID | CF-025 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-16 / F-25 Telemetry and SLOs |
| Owning service or application | `docs` |
| Priority | P1 |
| Dependencies | [CF-018](TASKS.md#cf-018) |
| Required agent | `commerce-architect` |
| Required skills | `architecture-decision-records`, `performance-testing` |

**Description.** Latency, availability and saga completion SLOs from business needs and baselines.

**Acceptance criteria**

- ADR accepted

**Test requirements**

- none (decision)

**Definition of Done** — general DoD, plus:

- k6 thresholds read from SLO values

### CF-070

**Secret and dependency scanning in CI**

| Field | Value |
|---|---|
| Task ID | CF-070 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-17 / F-27 Supply chain and secrets |
| Owning service or application | `.github/workflows` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020) |
| Required agent | `devops-engineer` |
| Required skills | `security-review`, `github-actions-cicd` |

**Description.** gitleaks, govulncheck, npm audit, Gradle dependency check, Trivy image scan per component.

**Acceptance criteria**

- High/critical findings fail the pipeline

**Test requirements**

- seeded vulnerable fixture detected

**Definition of Done** — general DoD, plus:

- security-audit approve

### CF-071

**Threat model and security audit per release**

| Field | Value |
|---|---|
| Task ID | CF-071 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-17 / F-26 Identity and authorization |
| Owning service or application | `all` |
| Priority | P1 |
| Dependencies | [CF-068](TASKS.md#cf-068), [CF-024](TASKS.md#cf-024) |
| Required agent | `security-reviewer` |
| Required skills | `security-audit`, `security-review` |

**Description.** STRIDE review of edge, identity, payment and data flows.

**Acceptance criteria**

- No open critical/high findings

**Test requirements**

- scanner runs

**Definition of Done** — general DoD, plus:

- Findings tracked

### CF-079

**Service dashboards and alert rules**

| Field | Value |
|---|---|
| Task ID | CF-079 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-16 / F-25 Telemetry and SLOs |
| Owning service or application | `infrastructure/monitoring` |
| Priority | P1 |
| Dependencies | [CF-012](TASKS.md#cf-012), [CF-059](TASKS.md#cf-059) |
| Required agent | `devops-engineer` |
| Required skills | `observability` |

**Description.** RED + messaging + business dashboards per service; alert rules with runbook links.

**Acceptance criteria**

- promtool check rules passes

**Test requirements**

- promtool test rules

**Definition of Done** — general DoD, plus:

- Runbooks linked

## Phase 12 — Kubernetes and production readiness

### CF-019

**Helm chart template and per-service values**

| Field | Value |
|---|---|
| Task ID | CF-019 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-29 Cluster and cloud |
| Owning service or application | `infrastructure/kubernetes` |
| Priority | P1 |
| Dependencies | [CF-032](TASKS.md#cf-032) |
| Required agent | `devops-engineer` |
| Required skills | `docker-kubernetes` |

**Description.** One chart template; values per service with probes, resources, security context, secret refs.

**Acceptance criteria**

- helm lint/template pass for all 10

**Test requirements**

- helm template + schema validation

**Definition of Done** — general DoD, plus:

- code-review approve

### CF-026

**Data retention with legal input**

| Field | Value |
|---|---|
| Task ID | CF-026 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-30 Operations and data governance |
| Owning service or application | `docs, services` |
| Priority | P1 |
| Dependencies | [CF-001](TASKS.md#cf-001) |
| Required agent | `commerce-architect` |
| Required skills | `architecture-decision-records` |

**Description.** Retention for orders, payments, customer data, backups; erasure flow.

**Acceptance criteria**

- Policy approved
- Retention jobs implemented

**Test requirements**

- retention job tests

**Definition of Done** — general DoD, plus:

- data-retention-policy.md updated

### CF-027

**RPO/RTO, backups and restore drills**

| Field | Value |
|---|---|
| Task ID | CF-027 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-30 Operations and data governance |
| Owning service or application | `infrastructure` |
| Priority | P1 |
| Dependencies | [CF-004](TASKS.md#cf-004) |
| Required agent | `devops-engineer` |
| Required skills | `observability` |

**Description.** Targets agreed with the business, backup topology, restore test.

**Acceptance criteria**

- Restore drill meets agreed targets

**Test requirements**

- restore drill

**Definition of Done** — general DoD, plus:

- disaster-recovery.md updated

### CF-080

**Dependency-aware CI triggering**

| Field | Value |
|---|---|
| Task ID | CF-080 |
| Status | 🟡 In progress — path filters per component include consumed/produced contract folders from the event catalogue; parity test with affected-components.ps1 not written |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `.github/workflows` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-002](TASKS.md#cf-002) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd` |

**Description.** Path filters per component include consumed contracts (from the event catalogue); a contract change triggers every producer and consumer pipeline and the compatibility job.

**Acceptance criteria**

- Changing cf.order events triggers order, inventory, payment, shipping, notification
- Unrelated change triggers nothing else

**Test requirements**

- affected-components.ps1 parity test

**Definition of Done** — general DoD, plus:

- Documented

### CF-081

**Kubernetes base: namespaces, network policies, quotas**

| Field | Value |
|---|---|
| Task ID | CF-081 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-29 Cluster and cloud |
| Owning service or application | `infrastructure/kubernetes` |
| Priority | P1 |
| Dependencies | [CF-004](TASKS.md#cf-004) |
| Required agent | `devops-engineer` |
| Required skills | `docker-kubernetes`, `security-review` |

**Description.** Network policies enforce database-per-service and allowed APIs.

**Acceptance criteria**

- Policy test shows a service cannot reach another database

**Test requirements**

- policy tests in a local cluster

**Definition of Done** — general DoD, plus:

- security-audit approve

### CF-083

**Production Debezium: heartbeats, failover slots, Connect HA**

| Field | Value |
|---|---|
| Task ID | CF-083 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-29 Cluster and cloud |
| Owning service or application | `infrastructure/debezium` |
| Priority | P1 |
| Dependencies | [CF-004](TASKS.md#cf-004), [CF-037](TASKS.md#cf-037) |
| Required agent | `event-driven-engineer` |
| Required skills | `debezium-cdc` |

**Description.** Heartbeat action query, failover slot handling, multi-worker Connect.

**Acceptance criteria**

- Idle-database slot lag stays bounded in staging

**Test requirements**

- staging failover drill

**Definition of Done** — general DoD, plus:

- Runbook updated

### CF-084

**product-service: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-084 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `services/product-service` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-040](TASKS.md#cf-040), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for services/product-service using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under services/product-service (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-085

**order-service: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-085 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `services/order-service` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-040](TASKS.md#cf-040), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for services/order-service using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under services/order-service (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-086

**payment-service: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-086 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `services/payment-service` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-040](TASKS.md#cf-040), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for services/payment-service using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under services/payment-service (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-087

**customer-service: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-087 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `services/customer-service` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-040](TASKS.md#cf-040), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for services/customer-service using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under services/customer-service (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-088

**pricing-service: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-088 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `services/pricing-service` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-040](TASKS.md#cf-040), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for services/pricing-service using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under services/pricing-service (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-089

**inventory-service: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-089 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `services/inventory-service` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-040](TASKS.md#cf-040), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for services/inventory-service using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under services/inventory-service (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-090

**shipping-service: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-090 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `services/shipping-service` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-040](TASKS.md#cf-040), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for services/shipping-service using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under services/shipping-service (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-091

**notification-service: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-091 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `services/notification-service` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-040](TASKS.md#cf-040), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for services/notification-service using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under services/notification-service (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-092

**admin-web: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-092 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `apps/admin-web` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for apps/admin-web using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under apps/admin-web (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-093

**storefront-web: own CI pipeline, image publish and staged deployment**

| Field | Value |
|---|---|
| Task ID | CF-093 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-28 CI/CD per component |
| Owning service or application | `apps/storefront-web` |
| Priority | P1 |
| Dependencies | [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-080](TASKS.md#cf-080), [CF-017](TASKS.md#cf-017) |
| Required agent | `devops-engineer` |
| Required skills | `github-actions-cicd`, `docker-kubernetes`, `contract-testing` |

**Description.** Workflow for apps/storefront-web using the reusable template: build, unit + integration tests, contract checks, scans, image tagged by git SHA, Helm release to staging then production with approval and can-i-deploy.

**Acceptance criteria**

- Only changes under apps/storefront-web (or its contracts) trigger it
- Image digest promoted unchanged staging → production
- Deployment blocked when contract checks fail

**Test requirements**

- pipeline dry run
- rollback by redeploying the previous image

**Definition of Done** — general DoD, plus:

- No deploy without approval

### CF-004

**Choose cloud provider and Terraform state backend**

| Field | Value |
|---|---|
| Task ID | CF-004 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-29 Cluster and cloud |
| Owning service or application | `infrastructure` |
| Priority | P2 |
| Dependencies | [CF-001](TASKS.md#cf-001) |
| Required agent | `commerce-architect` |
| Required skills | `architecture-decision-records` |

**Description.** Decide provider, managed vs self-run PostgreSQL/Kafka/Redis, registry, Terraform location and state.

**Acceptance criteria**

- ADR written and accepted
- Managed PostgreSQL supports logical replication and slot management

**Test requirements**

- none (decision)

**Definition of Done** — general DoD, plus:

- ADR accepted

### CF-082

**Terraform baseline**

| Field | Value |
|---|---|
| Task ID | CF-082 |
| Status | ⬜ Not started |
| Epic / feature | CF-EPIC-18 / F-29 Cluster and cloud |
| Owning service or application | `infrastructure` |
| Priority | P2 |
| Dependencies | [CF-004](TASKS.md#cf-004) |
| Required agent | `devops-engineer` |
| Required skills | `docker-kubernetes` |

**Description.** Network, cluster, managed data services; state backend.

**Acceptance criteria**

- terraform validate and plan succeed against a sandbox account

**Test requirements**

- terraform validate

**Definition of Done** — general DoD, plus:

- No apply by Claude
