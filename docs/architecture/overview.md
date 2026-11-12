# CommerceFlow architecture — overview and index

Status: **target architecture, mostly planned.** This page summarises the architecture,
states what exists today, and links to the detailed documents.

Legend used in every document: **Implemented** = exists in this repository and was
verified · **Planned** = designed, not built · **Open** = decision not made yet.

## Implemented vs planned

| Area | Implemented today | Planned |
|---|---|---|
| Repository | Monorepo layout; buildable scaffolds for 8 services and 2 apps (own build, health/readiness, migrations baseline, unit + integration tests, Dockerfile) and build/test scripts | Business logic, APIs, Kafka integration |
| Documentation | This architecture set, ADRs 0001–0011, event catalogue, agent/skill/workflow/hook catalogs | Runbooks (CF-023) |
| Engineering tooling | Claude Code agents, skills, workflows, hooks (+ hook tests), `scripts/affected-components.ps1` | CI workflows (CF-020) |
| Contracts | Rules for events (`contracts/events/README.md`) | Avro schemas (CF-002), OpenAPI specs |
| Runtime | — (placeholder `docker-compose.yml` with no services) | Compose stack (CF-005), Kubernetes, gateway, BFF |

Services start and report health locally, but no business API, event, shared database or pipeline exists yet.

## Architecture in one paragraph

Eight services, one per bounded context, live in one repository but build, test, deploy and
scale independently (ADR-0004, ADR-0011). Each owns its PostgreSQL database (ADR-0005).
Services publish facts through a transactional outbox (ADR-0006) relayed by Debezium
(ADR-0007) to Kafka (ADR-0008); consumers are idempotent through an inbox. Order placement
is a saga orchestrated by order-service (ADR-0009). Browsers reach services through an API
gateway, and admin-web through a backend-for-frontend (ADR-0010). Five services use
Kotlin/Spring Boot and three use Go (ADR-0003). Telemetry uses OpenTelemetry with
Prometheus, Grafana, Loki and Tempo.

## Goals

- Independent deployability of each bounded context.
- No distributed transactions; consistency through events and sagas.
- At-least-once delivery with idempotent processing.
- End-to-end traceability across HTTP and Kafka.

Performance and availability targets are **not defined yet** (CF-025, CF-027).

## Document index

### System

| Document | Content |
|---|---|
| [system-context.md](system-context.md) | Actors, external systems, scope (diagram) |
| [container-architecture.md](container-architecture.md) | Deployable units and data stores (diagram) |
| [deployment-architecture.md](deployment-architecture.md) | Environments and Kubernetes target (diagram) |
| [service-definitions.md](service-definitions.md) | The ten components in detail |
| [service-responsibility-matrix.md](service-responsibility-matrix.md) | Capability ownership and RACI |
| [service-catalog.md](service-catalog.md) | Paths, languages, databases, local ports |
| [bounded-context-map.md](bounded-context-map.md) | Context relationships and language (diagram) |
| [communication-patterns.md](communication-patterns.md) | Events, commands, sync calls; CDC flow, order saga, payment compensation (diagrams) |
| [monorepo-structure.md](monorepo-structure.md) | Repository layout and independence rules |
| [build-and-release-strategy.md](build-and-release-strategy.md) | Per-service pipelines and release gates |

### Data

| Document | Content |
|---|---|
| [database-ownership.md](database-ownership.md) | Databases, roles, tables, projections |
| [database-naming-conventions.md](database-naming-conventions.md) | Names for databases, tables, constraints, keys |
| [migration-strategy.md](migration-strategy.md) | Expand/contract, safe operations, execution |
| [data-retention-policy.md](data-retention-policy.md) | Retention (draft; legal input open) |

### Events

In [`../event-catalog/`](../event-catalog/README.md): event-driven architecture, detailed
catalogue, naming, versioning, outbox, Debezium, topics, retry and DLQ.

### API

| Document | Content |
|---|---|
| [api-standards.md](api-standards.md) | Resource design, errors, idempotency, concurrency |
| [api-versioning.md](api-versioning.md) | Path versioning and lifecycle |
| [authentication-authorization.md](authentication-authorization.md) | Identities, token validation, authorization levels |

### Quality

| Document | Content |
|---|---|
| [testing-strategy.md](testing-strategy.md) | Pyramid and where tests live |
| [observability-strategy.md](observability-strategy.md) | Signals, async tracing, alerts |
| [security-architecture.md](security-architecture.md) | Trust boundaries and controls |
| [disaster-recovery.md](disaster-recovery.md) | Recovery mechanisms and order |

### Decisions

[`../adr/README.md`](../adr/README.md) — ADRs 0001–0011.

## Diagrams

| Diagram | Location |
|---|---|
| System context | [system-context.md](system-context.md) |
| Container architecture | [container-architecture.md](container-architecture.md) |
| Product creation CDC flow | [communication-patterns.md](communication-patterns.md), [../event-catalog/debezium-design.md](../event-catalog/debezium-design.md) |
| Order saga (sequence and state machine) | [communication-patterns.md](communication-patterns.md) |
| Payment compensation | [communication-patterns.md](communication-patterns.md) |
| Retry and DLQ | [../event-catalog/retry-and-dlq-strategy.md](../event-catalog/retry-and-dlq-strategy.md) |
| Deployment architecture | [deployment-architecture.md](deployment-architecture.md) |

All diagrams are Mermaid.

## Service anatomy (Clean Architecture)

```text
adapters/in  (REST, Kafka listeners + inbox)
      │
application  (use cases, ports)
      │
domain       (aggregates, value objects, domain events — no framework code)
      ▲
adapters/out (PostgreSQL repositories, outbox writer, HTTP clients, Redis)
```

## CQRS (where justified)

- **Catalog browse**: storefront reads a denormalised read model (product + current price +
  availability) built from events; owner open (CF-015).
- **Order history**: projection inside order-service.

Other services use a single model.

## Open questions

Tracked in `backlog/BACKLOG.md` (items tagged `decision`): cloud provider (CF-004), cart
ownership (CF-014), catalog read model (CF-015), payment provider (CF-016), gateway and BFF
build (CF-024), SLOs (CF-025), retention (CF-026), RPO/RTO (CF-027).
