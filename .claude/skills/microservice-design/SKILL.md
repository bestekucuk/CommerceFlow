---
name: microservice-design
description: Design, add or change a CommerceFlow microservice boundary inside the modular monorepo - service responsibilities, data ownership, sync vs async integration, and the checklist that keeps each service independently buildable, deployable and scalable. Use when creating a service, splitting or merging responsibilities, or adding a dependency between services.
---

# Microservice design

## Purpose

Keep CommerceFlow a set of independent services that happen to share one Git repository
(ADR-0004). This skill turns a capability request into a service design: which bounded
context owns it, what data it owns, how it integrates, and what must exist in the repo for
the service to build and deploy on its own.

## When to use

- Adding a new service under `services/`.
- Moving a responsibility from one service to another.
- Adding any new dependency between services (event subscription or HTTP call).
- Reviewing a design that feels like it is turning into a distributed monolith.

## Prerequisites

- Read `docs/architecture/overview.md`, `docs/architecture/service-catalog.md`,
  `docs/event-catalog/README.md` and ADR-0002/0003/0004.
- Know the bounded context (see `domain-driven-design`).
- The `commerce-architect` agent owns the design; implementation is handed to the language
  engineer afterwards.

## Concepts and architecture

**Independence properties every service must keep**

| Property | What it means here |
|---|---|
| Independently buildable | Own build in its folder (`gradlew` or `go.mod` + Makefile). No root build. |
| Independently testable | `./gradlew test` / `go test ./...` from the folder passes with only Docker available. |
| Independently deployable | Own image, own Helm release, own CI workflow with path filters. |
| Independently scalable | Stateless process; state in its own PostgreSQL/Redis; Kafka consumer group per service. |
| Data ownership | Exactly one database `<name>_db`; nobody else connects to it. |

**Integration styles**

- **Events (default):** the owner publishes facts through the outbox; others keep local
  projections. Temporal decoupling, eventual consistency.
- **Commands over Kafka:** only inside the order saga (`cf.<aggregate>.commands.v1`).
- **Synchronous HTTP:** only when the caller needs fresh data *now* and cannot work with a
  projection (e.g. price quote at checkout). Always with timeout, retry budget and fallback.

**What may be shared:** contracts in `contracts/` (schemas only). Each service generates
its own types from them. CI templates in `.github/workflows/` may be reused; runtime
libraries may not.

## Step-by-step workflow

1. **Name the capability** and the bounded context that owns its invariants. If no
   context owns it, consider a new service; if one does, extend it.
2. **List the data** the capability writes. Exactly one service may write each datum.
3. **List the data it reads** from other contexts. Prefer a local projection built from
   events; justify every synchronous read.
4. **Define the contracts**: events produced (past tense), commands handled, HTTP API
   (OpenAPI in `contracts/openapi/<service>.v1.yaml`).
5. **Check failure modes**: what happens if each dependency is down for 10 minutes?
6. **Write the ADR** if a boundary moves or a new service is added
   (`architecture-decision-records`).
7. **Create the repository footprint** (new service only) — checklist below.
8. **Update catalogs**: `docs/architecture/service-catalog.md`,
   `docs/event-catalog/README.md`, `docs/agent-catalog.md` ownership map.

## Practical code examples

New-service footprint checklist (all paths relative to repo root):

```text
services/<name>-service/README.md, CLAUDE.md        purpose, context, owned DB, events
services/<name>-service/<build files>               see kotlin-springboot / golang-development
services/<name>-service/Dockerfile                  see docker-kubernetes
contracts/openapi/<name>-service.v1.yaml            if it exposes HTTP
contracts/events/<aggregate>/*.avsc                 if it publishes events
infrastructure/postgres/init/<name>.sql             database + user + publication
infrastructure/debezium/<name>-outbox.json          if it publishes events
docker-compose.yml                                  service + dependencies
.github/workflows/<name>-service.yml                path-filtered pipeline
infrastructure/kubernetes/helm/values/<name>-service.yaml
```

Path filter that keeps the pipeline independent:

```yaml
on:
  pull_request:
    paths:
      - "services/order-service/**"
      - "contracts/events/order/**"
      - "contracts/events/inventory/**"   # consumed
      - "contracts/events/payment/**"     # consumed
      - "contracts/openapi/order-service.*"
      - ".github/workflows/order-service.yml"
```

Synchronous call budget (Kotlin, Spring `RestClient`), used only after justification:

```kotlin
@Bean
fun pricingClient(builder: RestClient.Builder): RestClient =
    builder
        .baseUrl(env.getRequiredProperty("pricing.base-url"))
        .requestFactory(ClientHttpRequestFactories.get(
            ClientHttpRequestFactorySettings.DEFAULTS
                .withConnectTimeout(Duration.ofMillis(300))
                .withReadTimeout(Duration.ofMillis(800))))
        .build()
```

## Recommended project structure

```text
services/
  <name>-service/          one bounded context, own build, own Dockerfile
contracts/
  events/<aggregate>/      published language (Avro)
  openapi/<service>.v1.yaml
docs/architecture/service-catalog.md   single list of services, ports, DBs
```

## Best practices

- Design around business capabilities and invariants, not around entities or tables.
- Make the owner of an invariant the only writer of the data the invariant protects.
- Prefer one coarse event over several chatty ones; consumers build what they need.
- Keep synchronous chains at depth 1 (caller → owner), never A → B → C.
- Give every service its own Kafka consumer group id: `<service>` (e.g. `inventory-service`).
- Add the service to the catalogs in the same change that creates it.

## Anti-patterns

- **Shared database or schema**, even "read-only" access — couples deployments and schemas.
- **Shared domain library** (`commons-domain`) — every change redeploys every service.
- **Root multi-project build** compiling all services together.
- **Entity services** (`ProductDataService`) with no behaviour, called synchronously by
  everyone.
- **Distributed transaction** (2PC) across services — use a saga.
- **Event carrying another context's state** that the consumer then treats as truth.

## Failure scenarios

| Scenario | Design response |
|---|---|
| Synchronous dependency slow | Timeouts, circuit breaker, degrade (cached price, "temporarily unavailable"). |
| Event consumer down for hours | Kafka retention ≥ 7 days; consumer catches up; projections are rebuildable. |
| Two services both write "stock" | Boundary bug: move the write to one owner, the other emits a command/event. |
| New service needs historical data | Replay topic from earliest offset into a new consumer group, or request a bulk export event. |

## Testing strategy

- Service-local: unit + Testcontainers integration tests from the service folder.
- Cross-service behaviour: `tests/integration/` against Compose.
- HTTP dependencies: Pact (`contract-testing`); event dependencies: schema compatibility
  (`schema-evolution`).
- Architecture: ArchUnit / import checks that fail on cross-service imports
  (`clean-architecture`).

## Definition of Done

- One owning context for every datum and invariant in the design.
- Integration style chosen and justified per dependency.
- Contracts listed with producer and consumers; catalogs updated.
- Failure behaviour defined for every dependency.
- ADR written when a boundary moved or a service was added.
- New-service footprint checklist complete (for new services).
