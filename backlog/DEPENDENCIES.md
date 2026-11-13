# Dependencies

Status legend: ✅ Done = verified in this repository (evidence given) · 🟡 In progress · ⛔ Blocked · ⬜ Not started.
Generated from one data source; IDs `CF-0xx` keep the numbers already used in `docs/`. Snapshot: 2026-11-12.

Arrows point from a prerequisite to the task that needs it. Colours: green done, yellow in progress, red blocked, grey not started.

```mermaid
flowchart LR
    subgraph P1["Phase 1: Engineering foundation"]
        CF001["CF-001<br/>Accept or revise ADRs 0005-0011"]:::todo
        CF003["CF-003<br/>Contract code generation tooling"]:::wip
        CF021["CF-021<br/>Per-component build and test scripts"]:::done
        CF030["CF-030<br/>Modular monorepo layout and root guide"]:::done
        CF031["CF-031<br/>Architecture documentation set"]:::done
        CF032["CF-032<br/>Buildable scaffolds for 8 services and"]:::done
    end
    subgraph P2["Phase 2: Claude Code framework"]
        CF033["CF-033<br/>Claude Code agent team"]:::done
        CF034["CF-034<br/>Engineering skills library and workflo"]:::done
        CF035["CF-035<br/>Guardrail hooks with tests"]:::done
        CF036["CF-036<br/>Observe hooks in a live Claude session"]:::wip
    end
    subgraph P3["Phase 3: Local infrastructure"]
        CF005["CF-005<br/>Local Compose infrastructure stack"]:::done
        CF037["CF-037<br/>Verify CDC end to end locally"]:::done
        CF038["CF-038<br/>Wire application services and Toxiprox"]:::wip
        CF039["CF-039<br/>Expose Kafka Connect/Debezium metrics"]:::todo
    end
    subgraph P4["Phase 4: Product Service and CDC"]
        CF002["CF-002<br/>v1 Avro schemas for the core event cat"]:::wip
        CF040["CF-040<br/>Shared contract compatibility testing"]:::todo
        CF043["CF-043<br/>product-service: Product aggregate and"]:::done
        CF044["CF-044<br/>product-service: ProductCreated throug"]:::done
        CF045["CF-045<br/>Vertical slice: product created reache"]:::done
    end
    subgraph P5["Phase 5: Inventory and Customer"]
        CF046["CF-046<br/>inventory-service: consume ProductCrea"]:::done
        CF047["CF-047<br/>inventory-service: stock adjustment AP"]:::todo
        CF048["CF-048<br/>inventory-service: ReserveInventory / "]:::todo
        CF050["CF-050<br/>customer-service: profile and address "]:::todo
        CF051["CF-051<br/>customer-service: CustomerRegistered /"]:::todo
        CF052["CF-052<br/>pricing-service: prices with ETag and "]:::wip
        CF094["CF-094<br/>Outbox and inbox retention jobs"]:::todo
    end
    subgraph P6["Phase 6: Order and Payment"]
        CF014["CF-014<br/>Decide cart ownership"]:::wip
        CF016["CF-016<br/>Choose payment provider and sandbox; d"]:::todo
        CF053["CF-053<br/>pricing-service: price quote API"]:::wip
        CF055["CF-055<br/>order-service: create order (202, idem"]:::todo
        CF056["CF-056<br/>order-service: order history read mode"]:::todo
        CF057["CF-057<br/>payment-service: AuthorizePayment / Vo"]:::todo
    end
    subgraph P7["Phase 7: Saga and asynchronous workflows"]
        CF010["CF-010<br/>Order saga happy path end to end"]:::todo
        CF011["CF-011<br/>Saga compensation and timeouts"]:::todo
        CF023["CF-023<br/>Runbooks: slot growth, DLT replay, stu"]:::todo
        CF042["CF-042<br/>DLT replay tool"]:::todo
        CF049["CF-049<br/>inventory-service: commit reservation "]:::todo
        CF059["CF-059<br/>Stuck-saga metric and saga status endp"]:::todo
        CF060["CF-060<br/>shipping-service: shipment from OrderC"]:::todo
        CF061["CF-061<br/>shipping-service: carrier adapter stub"]:::todo
        CF062["CF-062<br/>Cancel a confirmed order (OrderCancell"]:::todo
        CF063["CF-063<br/>notification-service: email notificati"]:::todo
    end
    subgraph P8["Phase 8: Admin Dashboard"]
        CF024["CF-024<br/>API gateway and admin BFF"]:::todo
        CF064["CF-064<br/>admin-web: login and role-gated routes"]:::todo
        CF065["CF-065<br/>Local identity provider (Keycloak) and"]:::todo
        CF066["CF-066<br/>admin-web: catalog and price managemen"]:::todo
        CF067["CF-067<br/>admin-web: orders and saga status"]:::todo
        CF068["CF-068<br/>JWT resource server in every service"]:::todo
    end
    subgraph P9["Phase 9: Storefront"]
        CF015["CF-015<br/>Decide catalog read model ownership"]:::todo
        CF072["CF-072<br/>Catalog read model"]:::todo
        CF073["CF-073<br/>storefront-web: browse and product det"]:::todo
        CF074["CF-074<br/>storefront-web: checkout and order sta"]:::todo
        CF075["CF-075<br/>storefront-web: order history"]:::todo
    end
    subgraph P10["Phase 10: Complete testing"]
        CF017["CF-017<br/>Pact consumer/provider and broker"]:::todo
        CF018["CF-018<br/>k6 baselines for browse and checkout"]:::todo
        CF020["CF-020<br/>Reusable CI workflows per language"]:::wip
        CF022["CF-022<br/>Architecture tests in every service"]:::wip
        CF076["CF-076<br/>Cross-service integration suite"]:::todo
        CF077["CF-077<br/>Cross-app Playwright journeys"]:::todo
        CF078["CF-078<br/>Resilience scenario catalogue R1-R6"]:::todo
    end
    subgraph P11["Phase 11: Observability and security"]
        CF012["CF-012<br/>OpenTelemetry in all services, trace t"]:::todo
        CF025["CF-025<br/>Define SLOs"]:::todo
        CF070["CF-070<br/>Secret and dependency scanning in CI"]:::todo
        CF071["CF-071<br/>Threat model and security audit per re"]:::todo
        CF079["CF-079<br/>Service dashboards and alert rules"]:::todo
    end
    subgraph P12["Phase 12: Kubernetes and production readiness"]
        CF004["CF-004<br/>Choose cloud provider and Terraform st"]:::todo
        CF019["CF-019<br/>Helm chart template and per-service va"]:::todo
        CF026["CF-026<br/>Data retention with legal input"]:::todo
        CF027["CF-027<br/>RPO/RTO, backups and restore drills"]:::todo
        CF080["CF-080<br/>Dependency-aware CI triggering"]:::wip
        CF081["CF-081<br/>Kubernetes base: namespaces, network p"]:::todo
        CF082["CF-082<br/>Terraform baseline"]:::todo
        CF083["CF-083<br/>Production Debezium: heartbeats, failo"]:::todo
        CF090["CF-090<br/>shipping-service: own CI pipeline, ima"]:::todo
        CF091["CF-091<br/>notification-service: own CI pipeline,"]:::todo
        CF092["CF-092<br/>admin-web: own CI pipeline, image publ"]:::todo
        CF093["CF-093<br/>storefront-web: own CI pipeline, image"]:::todo
        SVCPIPE["CF-084..CF-093<br/>per-component pipelines (10)"]:::todo
    end
    CF030 --> CF031
    CF031 --> CF001
    CF030 --> CF021
    CF021 --> CF032
    CF032 --> CF003
    CF001 --> CF004
    CF030 --> CF033
    CF033 --> CF034
    CF034 --> CF035
    CF035 --> CF036
    CF032 --> CF005
    CF005 --> CF037
    CF005 --> CF038
    CF032 --> CF038
    CF005 --> CF039
    CF031 --> CF002
    CF002 --> CF040
    CF005 --> CF040
    CF032 --> CF043
    CF043 --> CF044
    CF044 --> CF045
    CF037 --> CF045
    CF044 --> CF094
    CF046 --> CF094
    CF045 --> CF046
    CF046 --> CF047
    CF046 --> CF048
    CF002 --> CF048
    CF032 --> CF050
    CF050 --> CF051
    CF002 --> CF051
    CF045 --> CF052
    CF052 --> CF053
    CF001 --> CF014
    CF053 --> CF055
    CF050 --> CF055
    CF055 --> CF056
    CF001 --> CF016
    CF002 --> CF057
    CF032 --> CF057
    CF055 --> CF010
    CF048 --> CF010
    CF057 --> CF010
    CF038 --> CF010
    CF010 --> CF011
    CF010 --> CF059
    CF010 --> CF062
    CF060 --> CF062
    CF048 --> CF049
    CF010 --> CF049
    CF010 --> CF060
    CF060 --> CF061
    CF010 --> CF063
    CF051 --> CF063
    CF046 --> CF042
    CF042 --> CF023
    CF059 --> CF023
    CF005 --> CF065
    CF065 --> CF068
    CF065 --> CF024
    CF001 --> CF024
    CF024 --> CF064
    CF064 --> CF066
    CF043 --> CF066
    CF052 --> CF066
    CF064 --> CF067
    CF059 --> CF067
    CF001 --> CF015
    CF015 --> CF072
    CF052 --> CF072
    CF047 --> CF072
    CF072 --> CF073
    CF024 --> CF073
    CF055 --> CF074
    CF065 --> CF074
    CF014 --> CF074
    CF056 --> CF075
    CF074 --> CF075
    CF032 --> CF022
    CF073 --> CF017
    CF055 --> CF017
    CF010 --> CF076
    CF038 --> CF076
    CF066 --> CF077
    CF074 --> CF077
    CF010 --> CF018
    CF073 --> CF018
    CF011 --> CF078
    CF038 --> CF078
    CF045 --> CF012
    CF012 --> CF079
    CF059 --> CF079
    CF018 --> CF025
    CF020 --> CF070
    CF068 --> CF071
    CF024 --> CF071
    CF021 --> CF020
    CF020 --> CF080
    CF002 --> CF080
    CF032 --> CF019
    CF004 --> CF081
    CF004 --> CF082
    CF004 --> CF083
    CF037 --> CF083
    CF004 --> CF027
    CF001 --> CF026
    CF020 --> SVCPIPE
    CF019 --> SVCPIPE
    CF080 --> SVCPIPE
    CF040 --> SVCPIPE
    CF017 --> SVCPIPE
    classDef done fill:#d1f2d1,stroke:#2e7d32
    classDef wip fill:#fff4c2,stroke:#b8860b
    classDef blocked fill:#f8d0d0,stroke:#b71c1c
    classDef todo fill:#eeeeee,stroke:#757575
```

## Critical path (longest dependency chain)

[CF-030](TASKS.md#cf-030) → [CF-021](TASKS.md#cf-021) → [CF-032](TASKS.md#cf-032) → [CF-043](TASKS.md#cf-043) → [CF-044](TASKS.md#cf-044) → [CF-045](TASKS.md#cf-045) → [CF-052](TASKS.md#cf-052) → [CF-053](TASKS.md#cf-053) → [CF-055](TASKS.md#cf-055) → [CF-010](TASKS.md#cf-010) → [CF-060](TASKS.md#cf-060) → [CF-062](TASKS.md#cf-062)

## Vertical slice first

The first end-to-end slice proves the architecture before breadth: product created → outbox → Debezium → Kafka → inventory/pricing consume → order → saga confirmed.

[CF-005](TASKS.md#cf-005) → [CF-037](TASKS.md#cf-037) → [CF-002](TASKS.md#cf-002) → [CF-003](TASKS.md#cf-003) → [CF-043](TASKS.md#cf-043) → [CF-044](TASKS.md#cf-044) → [CF-038](TASKS.md#cf-038) → [CF-045](TASKS.md#cf-045) → [CF-046](TASKS.md#cf-046) → [CF-052](TASKS.md#cf-052) → [CF-053](TASKS.md#cf-053) → [CF-055](TASKS.md#cf-055) → [CF-048](TASKS.md#cf-048) → [CF-057](TASKS.md#cf-057) → [CF-010](TASKS.md#cf-010)

## Ready to start now (all dependencies done)

| Task | Title | Priority | Unblocks (transitively) |
|---|---|---|---|
| [CF-052](TASKS.md#cf-052) | pricing-service: prices with ETag and ProductPriceChanged | P0 | 35 tasks |
| [CF-001](TASKS.md#cf-001) | Accept or revise ADRs 0005-0011 | P0 | 32 tasks |
| [CF-002](TASKS.md#cf-002) | v1 Avro schemas for the core event catalogue | P0 | 30 tasks |
| [CF-065](TASKS.md#cf-065) | Local identity provider (Keycloak) and roles | P0 | 23 tasks |
| [CF-003](TASKS.md#cf-003) | Contract code generation tooling | P0 | 0 tasks |
| [CF-050](TASKS.md#cf-050) | customer-service: profile and address API | P1 | 32 tasks |
| [CF-038](TASKS.md#cf-038) | Wire application services and Toxiproxy into Compose | P1 | 15 tasks |
| [CF-047](TASKS.md#cf-047) | inventory-service: stock adjustment API | P1 | 15 tasks |
| [CF-020](TASKS.md#cf-020) | Reusable CI workflows per language | P1 | 12 tasks |
| [CF-019](TASKS.md#cf-019) | Helm chart template and per-service values | P1 | 10 tasks |
| [CF-012](TASKS.md#cf-012) | OpenTelemetry in all services, trace through outbox | P1 | 1 tasks |
| [CF-042](TASKS.md#cf-042) | DLT replay tool | P1 | 1 tasks |
| [CF-022](TASKS.md#cf-022) | Architecture tests in every service | P1 | 0 tasks |
| [CF-094](TASKS.md#cf-094) | Outbox and inbox retention jobs | P1 | 0 tasks |
| [CF-039](TASKS.md#cf-039) | Expose Kafka Connect/Debezium metrics | P2 | 0 tasks |
| [CF-036](TASKS.md#cf-036) | Observe hooks in a live Claude session | P3 | 0 tasks |

## Blocked


## Contract dependencies (monorepo rule)

- Any change in `contracts/events` must pass [CF-040](TASKS.md#cf-040) compatibility checks and trigger the pipelines of every producer and consumer ([CF-080](TASKS.md#cf-080)).
- Provider APIs consumed by apps or services are gated by Pact ([CF-017](TASKS.md#cf-017)) before deployment ([CF-084..CF-093](TASKS.md#phase-12--kubernetes-and-production-readiness)).
- Producer and consumer of one event are separate tasks and deploy separately: consumers first for additive changes (`docs/event-catalog/event-versioning-policy.md`).
