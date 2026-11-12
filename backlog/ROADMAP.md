# Roadmap

Status legend: ✅ Done = verified in this repository (evidence given) · 🟡 In progress · ⛔ Blocked · ⬜ Not started.
Generated from one data source; IDs `CF-0xx` keep the numbers already used in `docs/`. Snapshot: 2026-11-12.

83 tasks — ✅ Done: 13, 🟡 In progress: 7, ⛔ Blocked: 0, ⬜ Not started: 63

Phases are ordered by dependency, not by calendar; no dates are committed. The vertical slice (phases 3–7) is prioritised over breadth.

| Phase | Goal | Tasks | Done | Status |
|---|---|---|---|---|
| 1. Engineering foundation | One repository, documented architecture, every component builds on its own. | 6 | 4 | 🟡 In progress |
| 2. Claude Code framework | Claude works safely: agents, skills, workflows and guardrail hooks. | 4 | 3 | 🟡 In progress |
| 3. Local infrastructure | Local stack with per-service databases, Kafka, Debezium and observability, verified healthy; CDC verified end to end. | 4 | 2 | 🟡 In progress |
| 4. Product Service and CDC | **Vertical slice part 1**: product created via API reaches Kafka through outbox + Debezium with valid Avro; contract compatibility checks exist. | 5 | 3 | 🟡 In progress |
| 5. Inventory and Customer | Inventory and pricing consume product events idempotently; customer profile exists. | 7 | 1 | 🟡 In progress |
| 6. Order and Payment | Orders can be created against a quote; payment handles authorization and void. | 6 | 0 | ⬜ Not started |
| 7. Saga and asynchronous workflows | **Vertical slice part 2**: order saga confirms, compensates and times out correctly; shipping and notifications react. | 10 | 0 | ⬜ Not started |
| 8. Admin Dashboard | Staff manage catalog, prices and orders through the admin BFF with real identity. | 6 | 0 | ⬜ Not started |
| 9. Storefront | Customers browse, check out and track orders. | 5 | 0 | ⬜ Not started |
| 10. Complete testing | All test layers in place: architecture, contract, integration, E2E, performance baselines, resilience. | 7 | 0 | 🟡 In progress |
| 11. Observability and security | Tracing across async hops, dashboards, alerts, SLOs; security scanning and audits. | 5 | 0 | ⬜ Not started |
| 12. Kubernetes and production readiness | Per-component CI/CD, Helm/Kubernetes, Terraform, DR and retention ready for a first environment. | 18 | 0 | 🟡 In progress |

## Phase 1 — Engineering foundation

One repository, documented architecture, every component builds on its own.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-001](TASKS.md#cf-001) | Accept or revise ADRs 0005-0011 | `docs` | P0 | ⬜ Not started |
| [CF-003](TASKS.md#cf-003) | Contract code generation tooling | `contracts, services` | P0 | 🟡 In progress |
| [CF-021](TASKS.md#cf-021) | Per-component build and test scripts | `scripts` | P0 | ✅ Done |
| [CF-030](TASKS.md#cf-030) | Modular monorepo layout and root guides | `repository` | P0 | ✅ Done |
| [CF-031](TASKS.md#cf-031) | Architecture documentation set | `docs` | P0 | ✅ Done |
| [CF-032](TASKS.md#cf-032) | Buildable scaffolds for 8 services and 2 apps | `services/*, apps/*` | P0 | ✅ Done |

## Phase 2 — Claude Code framework

Claude works safely: agents, skills, workflows and guardrail hooks.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-033](TASKS.md#cf-033) | Claude Code agent team | `.claude/agents` | P0 | ✅ Done |
| [CF-034](TASKS.md#cf-034) | Engineering skills library and workflows | `.claude/skills` | P0 | ✅ Done |
| [CF-035](TASKS.md#cf-035) | Guardrail hooks with tests | `.claude/hooks` | P0 | ✅ Done |
| [CF-036](TASKS.md#cf-036) | Observe hooks in a live Claude session | `.claude/hooks` | P3 | 🟡 In progress |

## Phase 3 — Local infrastructure

Local stack with per-service databases, Kafka, Debezium and observability, verified healthy; CDC verified end to end.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-005](TASKS.md#cf-005) | Local Compose infrastructure stack | `infrastructure` | P0 | ✅ Done |
| [CF-037](TASKS.md#cf-037) | Verify CDC end to end locally | `infrastructure` | P0 | ✅ Done |
| [CF-038](TASKS.md#cf-038) | Wire application services and Toxiproxy into Compose | `infrastructure` | P1 | 🟡 In progress |
| [CF-039](TASKS.md#cf-039) | Expose Kafka Connect/Debezium metrics | `infrastructure` | P2 | ⬜ Not started |

## Phase 4 — Product Service and CDC

**Vertical slice part 1**: product created via API reaches Kafka through outbox + Debezium with valid Avro; contract compatibility checks exist.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-002](TASKS.md#cf-002) | v1 Avro schemas for the core event catalogue | `contracts/events` | P0 | 🟡 In progress |
| [CF-040](TASKS.md#cf-040) | Shared contract compatibility testing | `tests/contract` | P0 | ⬜ Not started |
| [CF-043](TASKS.md#cf-043) | product-service: Product aggregate and catalog API | `services/product-service` | P0 | ✅ Done |
| [CF-044](TASKS.md#cf-044) | product-service: ProductCreated through the outbox | `services/product-service` | P0 | ✅ Done |
| [CF-045](TASKS.md#cf-045) | Vertical slice: product created reaches Kafka via Debezium | `tests/integration` | P0 | ✅ Done |

## Phase 5 — Inventory and Customer

Inventory and pricing consume product events idempotently; customer profile exists.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-046](TASKS.md#cf-046) | inventory-service: consume ProductCreated with inbox and DLT | `services/inventory-service` | P0 | ✅ Done |
| [CF-048](TASKS.md#cf-048) | inventory-service: ReserveInventory / ReleaseInventory handlers | `services/inventory-service` | P0 | ⬜ Not started |
| [CF-052](TASKS.md#cf-052) | pricing-service: prices with ETag and ProductPriceChanged | `services/pricing-service` | P0 | ⬜ Not started |
| [CF-047](TASKS.md#cf-047) | inventory-service: stock adjustment API | `services/inventory-service` | P1 | ⬜ Not started |
| [CF-050](TASKS.md#cf-050) | customer-service: profile and address API | `services/customer-service` | P1 | ⬜ Not started |
| [CF-051](TASKS.md#cf-051) | customer-service: CustomerRegistered / CustomerContactChanged | `services/customer-service` | P1 | ⬜ Not started |
| [CF-094](TASKS.md#cf-094) | Outbox and inbox retention jobs | `services/*` | P1 | ⬜ Not started |

## Phase 6 — Order and Payment

Orders can be created against a quote; payment handles authorization and void.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-053](TASKS.md#cf-053) | pricing-service: price quote API | `services/pricing-service` | P0 | ⬜ Not started |
| [CF-055](TASKS.md#cf-055) | order-service: create order (202, idempotency key) and OrderCreated | `services/order-service` | P0 | ⬜ Not started |
| [CF-057](TASKS.md#cf-057) | payment-service: AuthorizePayment / VoidPayment with provider adapter | `services/payment-service` | P0 | ⬜ Not started |
| [CF-014](TASKS.md#cf-014) | Decide cart ownership | `docs` | P1 | ⬜ Not started |
| [CF-016](TASKS.md#cf-016) | Choose payment provider and sandbox; decide capture timing | `services/payment-service` | P1 | ⬜ Not started |
| [CF-056](TASKS.md#cf-056) | order-service: order history read model and GET APIs | `services/order-service` | P1 | ⬜ Not started |

## Phase 7 — Saga and asynchronous workflows

**Vertical slice part 2**: order saga confirms, compensates and times out correctly; shipping and notifications react.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-010](TASKS.md#cf-010) | Order saga happy path end to end | `services/order-service + inventory + payment` | P0 | ⬜ Not started |
| [CF-011](TASKS.md#cf-011) | Saga compensation and timeouts | `services/order-service + inventory + payment` | P0 | ⬜ Not started |
| [CF-023](TASKS.md#cf-023) | Runbooks: slot growth, DLT replay, stuck saga, registry rejects schema | `docs/runbooks` | P1 | ⬜ Not started |
| [CF-042](TASKS.md#cf-042) | DLT replay tool | `scripts` | P1 | ⬜ Not started |
| [CF-049](TASKS.md#cf-049) | inventory-service: commit reservation on OrderConfirmed and expiry | `services/inventory-service` | P1 | ⬜ Not started |
| [CF-059](TASKS.md#cf-059) | Stuck-saga metric and saga status endpoint | `services/order-service` | P1 | ⬜ Not started |
| [CF-060](TASKS.md#cf-060) | shipping-service: shipment from OrderConfirmed | `services/shipping-service` | P1 | ⬜ Not started |
| [CF-062](TASKS.md#cf-062) | Cancel a confirmed order (OrderCancelled flow) | `order + inventory + payment + shipping` | P1 | ⬜ Not started |
| [CF-063](TASKS.md#cf-063) | notification-service: email notifications for order lifecycle | `services/notification-service` | P1 | ⬜ Not started |
| [CF-061](TASKS.md#cf-061) | shipping-service: carrier adapter stub and tracking events | `services/shipping-service` | P2 | ⬜ Not started |

## Phase 8 — Admin Dashboard

Staff manage catalog, prices and orders through the admin BFF with real identity.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-024](TASKS.md#cf-024) | API gateway and admin BFF | `apps/admin-web, infrastructure` | P0 | ⬜ Not started |
| [CF-065](TASKS.md#cf-065) | Local identity provider (Keycloak) and roles | `infrastructure` | P0 | ⬜ Not started |
| [CF-068](TASKS.md#cf-068) | JWT resource server in every service | `services/*` | P0 | ⬜ Not started |
| [CF-064](TASKS.md#cf-064) | admin-web: login and role-gated routes | `apps/admin-web` | P1 | ⬜ Not started |
| [CF-066](TASKS.md#cf-066) | admin-web: catalog and price management | `apps/admin-web` | P1 | ⬜ Not started |
| [CF-067](TASKS.md#cf-067) | admin-web: orders and saga status | `apps/admin-web` | P2 | ⬜ Not started |

## Phase 9 — Storefront

Customers browse, check out and track orders.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-074](TASKS.md#cf-074) | storefront-web: checkout and order status | `apps/storefront-web` | P0 | ⬜ Not started |
| [CF-015](TASKS.md#cf-015) | Decide catalog read model ownership | `docs` | P1 | ⬜ Not started |
| [CF-072](TASKS.md#cf-072) | Catalog read model | `per CF-015` | P1 | ⬜ Not started |
| [CF-073](TASKS.md#cf-073) | storefront-web: browse and product detail | `apps/storefront-web` | P1 | ⬜ Not started |
| [CF-075](TASKS.md#cf-075) | storefront-web: order history | `apps/storefront-web` | P2 | ⬜ Not started |

## Phase 10 — Complete testing

All test layers in place: architecture, contract, integration, E2E, performance baselines, resilience.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-017](TASKS.md#cf-017) | Pact consumer/provider and broker | `apps, services, tests/contract` | P1 | ⬜ Not started |
| [CF-020](TASKS.md#cf-020) | Reusable CI workflows per language | `.github/workflows` | P1 | 🟡 In progress |
| [CF-022](TASKS.md#cf-022) | Architecture tests in every service | `services/*` | P1 | 🟡 In progress |
| [CF-076](TASKS.md#cf-076) | Cross-service integration suite | `tests/integration` | P1 | ⬜ Not started |
| [CF-078](TASKS.md#cf-078) | Resilience scenario catalogue R1-R6 | `tests/resilience` | P1 | ⬜ Not started |
| [CF-018](TASKS.md#cf-018) | k6 baselines for browse and checkout | `tests/performance` | P2 | ⬜ Not started |
| [CF-077](TASKS.md#cf-077) | Cross-app Playwright journeys | `tests/e2e` | P2 | ⬜ Not started |

## Phase 11 — Observability and security

Tracing across async hops, dashboards, alerts, SLOs; security scanning and audits.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-012](TASKS.md#cf-012) | OpenTelemetry in all services, trace through outbox | `services/*` | P1 | ⬜ Not started |
| [CF-025](TASKS.md#cf-025) | Define SLOs | `docs` | P1 | ⬜ Not started |
| [CF-070](TASKS.md#cf-070) | Secret and dependency scanning in CI | `.github/workflows` | P1 | ⬜ Not started |
| [CF-071](TASKS.md#cf-071) | Threat model and security audit per release | `all` | P1 | ⬜ Not started |
| [CF-079](TASKS.md#cf-079) | Service dashboards and alert rules | `infrastructure/monitoring` | P1 | ⬜ Not started |

## Phase 12 — Kubernetes and production readiness

Per-component CI/CD, Helm/Kubernetes, Terraform, DR and retention ready for a first environment.

| Task | Title | Owner | Priority | Status |
|---|---|---|---|---|
| [CF-019](TASKS.md#cf-019) | Helm chart template and per-service values | `infrastructure/kubernetes` | P1 | ⬜ Not started |
| [CF-026](TASKS.md#cf-026) | Data retention with legal input | `docs, services` | P1 | ⬜ Not started |
| [CF-027](TASKS.md#cf-027) | RPO/RTO, backups and restore drills | `infrastructure` | P1 | ⬜ Not started |
| [CF-080](TASKS.md#cf-080) | Dependency-aware CI triggering | `.github/workflows` | P1 | 🟡 In progress |
| [CF-081](TASKS.md#cf-081) | Kubernetes base: namespaces, network policies, quotas | `infrastructure/kubernetes` | P1 | ⬜ Not started |
| [CF-083](TASKS.md#cf-083) | Production Debezium: heartbeats, failover slots, Connect HA | `infrastructure/debezium` | P1 | ⬜ Not started |
| [CF-084](TASKS.md#cf-084) | product-service: own CI pipeline, image publish and staged deployment | `services/product-service` | P1 | ⬜ Not started |
| [CF-085](TASKS.md#cf-085) | order-service: own CI pipeline, image publish and staged deployment | `services/order-service` | P1 | ⬜ Not started |
| [CF-086](TASKS.md#cf-086) | payment-service: own CI pipeline, image publish and staged deployment | `services/payment-service` | P1 | ⬜ Not started |
| [CF-087](TASKS.md#cf-087) | customer-service: own CI pipeline, image publish and staged deployment | `services/customer-service` | P1 | ⬜ Not started |
| [CF-088](TASKS.md#cf-088) | pricing-service: own CI pipeline, image publish and staged deployment | `services/pricing-service` | P1 | ⬜ Not started |
| [CF-089](TASKS.md#cf-089) | inventory-service: own CI pipeline, image publish and staged deployment | `services/inventory-service` | P1 | ⬜ Not started |
| [CF-090](TASKS.md#cf-090) | shipping-service: own CI pipeline, image publish and staged deployment | `services/shipping-service` | P1 | ⬜ Not started |
| [CF-091](TASKS.md#cf-091) | notification-service: own CI pipeline, image publish and staged deployment | `services/notification-service` | P1 | ⬜ Not started |
| [CF-092](TASKS.md#cf-092) | admin-web: own CI pipeline, image publish and staged deployment | `apps/admin-web` | P1 | ⬜ Not started |
| [CF-093](TASKS.md#cf-093) | storefront-web: own CI pipeline, image publish and staged deployment | `apps/storefront-web` | P1 | ⬜ Not started |
| [CF-004](TASKS.md#cf-004) | Choose cloud provider and Terraform state backend | `infrastructure` | P2 | ⬜ Not started |
| [CF-082](TASKS.md#cf-082) | Terraform baseline | `infrastructure` | P2 | ⬜ Not started |

## Recommended next executable task

1. **[CF-005](TASKS.md#cf-005) — finish verifying the local stack** (files are written; the first start was interrupted by a Docker Engine error). Restart Docker Desktop, then `infrastructure/scripts/up.ps1` and `health.ps1`. It unblocks 53 tasks, including the CDC verification [CF-037](TASKS.md#cf-037).
2. In parallel, without Docker: **[CF-002](TASKS.md#cf-002) — v1 Avro schemas** (`/create-domain-event`, agent `event-driven-engineer`). It is P0, all its dependencies are done, and it unblocks 30 tasks on the vertical slice.
3. Then **[CF-003](TASKS.md#cf-003)** (codegen) and **[CF-043](TASKS.md#cf-043)** (product API) to complete phase 4 inputs.

Also ready: [CF-052](TASKS.md#cf-052), [CF-001](TASKS.md#cf-001), [CF-065](TASKS.md#cf-065), [CF-050](TASKS.md#cf-050), [CF-038](TASKS.md#cf-038), [CF-047](TASKS.md#cf-047), [CF-020](TASKS.md#cf-020), [CF-019](TASKS.md#cf-019), [CF-012](TASKS.md#cf-012), [CF-042](TASKS.md#cf-042), [CF-022](TASKS.md#cf-022), [CF-094](TASKS.md#cf-094), [CF-039](TASKS.md#cf-039), [CF-036](TASKS.md#cf-036).
