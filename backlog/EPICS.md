# Epics

Status legend: ✅ Done = verified in this repository (evidence given) · 🟡 In progress · ⛔ Blocked · ⬜ Not started.
Generated from one data source; IDs `CF-0xx` keep the numbers already used in `docs/`. Snapshot: 2026-11-12.

| Epic | Goal | Phases | Features | Tasks (done/total) | Status |
|---|---|---|---|---|---|
| **CF-EPIC-01** Engineering Foundation | Monorepo, architecture decisions, documentation, per-component builds and contract tooling. | 1 | F-01, F-02, F-03 | 4/6 | 🟡 In progress |
| **CF-EPIC-02** Claude Code Agent Framework | Agents, skills, workflows and hooks that let Claude work safely in the monorepo. | 2 | F-04, F-05 | 3/4 | 🟡 In progress |
| **CF-EPIC-03** Local Infrastructure | Docker Compose stack: PostgreSQL, Kafka, Debezium, Schema Registry, Redis, observability. | 3 | F-06, F-07 | 0/3 | 🟡 In progress |
| **CF-EPIC-04** Product Management | Catalog bounded context: products, SKUs, lifecycle, product events. | 4 | F-08, F-09 | 0/3 | ⬜ Not started |
| **CF-EPIC-05** Customer Management | Customer profiles, addresses, contact events. | 5 | F-10 | 0/2 | ⬜ Not started |
| **CF-EPIC-06** Inventory Management | Stock, reservations, saga participation. | 5, 7 | F-11, F-12 | 0/4 | ⬜ Not started |
| **CF-EPIC-07** Pricing and Promotions | Prices, price lists, quotes, promotions. | 5, 6 | F-13 | 0/2 | ⬜ Not started |
| **CF-EPIC-08** Order Management | Order aggregate, order creation, order history, saga orchestration. | 6, 7 | F-14, F-15 | 0/7 | ⬜ Not started |
| **CF-EPIC-09** Payment Management | Provider adapter, authorization, void, refund. | 6, 7 | F-16 | 0/2 | ⬜ Not started |
| **CF-EPIC-10** Shipping Management | Shipments, carrier adapter, tracking. | 7 | F-17 | 0/2 | ⬜ Not started |
| **CF-EPIC-11** Notification Processing | Customer notifications from order, payment and shipment events. | 7 | F-18 | 0/1 | ⬜ Not started |
| **CF-EPIC-12** Event Driven Architecture | Contracts, schema registry, compatibility, outbox/CDC, DLT tooling. | 4, 7 | F-19, F-20 | 0/5 | ⬜ Not started |
| **CF-EPIC-13** Admin Dashboard | Back-office UI through the admin BFF. | 8 | F-21 | 0/4 | ⬜ Not started |
| **CF-EPIC-14** Storefront | Customer UI, catalog read model, checkout. | 9 | F-22, F-23 | 0/5 | ⬜ Not started |
| **CF-EPIC-15** Testing and Quality | Architecture, contract, integration, E2E, performance and resilience tests. | 10 | F-24 | 0/6 | 🟡 In progress |
| **CF-EPIC-16** Observability | Tracing, metrics, logs, dashboards, alerts, SLOs. | 11 | F-25 | 0/3 | ⬜ Not started |
| **CF-EPIC-17** Security | Identity, authorization, secrets, scanning, threat models. | 8, 11 | F-26, F-27 | 0/4 | ⬜ Not started |
| **CF-EPIC-18** Production Readiness | CI/CD, Helm, Kubernetes, Terraform, DR, retention. | 12 | F-28, F-29, F-30 | 0/19 | ⬜ Not started |

## CF-EPIC-01 — Engineering Foundation

Monorepo, architecture decisions, documentation, per-component builds and contract tooling.

- **F-01 Repository and architecture baseline**: [CF-001](TASKS.md#cf-001) Accept or revise ADRs 0005-0011 (⬜ Not started), [CF-030](TASKS.md#cf-030) Modular monorepo layout and root guides (✅ Done), [CF-031](TASKS.md#cf-031) Architecture documentation set (✅ Done)
- **F-02 Per-component builds and scaffolds**: [CF-021](TASKS.md#cf-021) Per-component build and test scripts (✅ Done), [CF-032](TASKS.md#cf-032) Buildable scaffolds for 8 services and 2 apps (✅ Done)
- **F-03 Contract code generation**: [CF-003](TASKS.md#cf-003) Contract code generation tooling (⬜ Not started)

## CF-EPIC-02 — Claude Code Agent Framework

Agents, skills, workflows and hooks that let Claude work safely in the monorepo.

- **F-04 Agent team, skills and workflows**: [CF-033](TASKS.md#cf-033) Claude Code agent team (✅ Done), [CF-034](TASKS.md#cf-034) Engineering skills library and workflows (✅ Done)
- **F-05 Guardrail hooks**: [CF-035](TASKS.md#cf-035) Guardrail hooks with tests (✅ Done), [CF-036](TASKS.md#cf-036) Observe hooks in a live Claude session (🟡 In progress)

## CF-EPIC-03 — Local Infrastructure

Docker Compose stack: PostgreSQL, Kafka, Debezium, Schema Registry, Redis, observability.

- **F-06 Local Compose stack**: [CF-005](TASKS.md#cf-005) Local Compose infrastructure stack (🟡 In progress), [CF-038](TASKS.md#cf-038) Wire application services and Toxiproxy into Compose (⬜ Not started)
- **F-07 Local CDC pipeline**: [CF-037](TASKS.md#cf-037) Verify CDC end to end locally (⬜ Not started)

## CF-EPIC-04 — Product Management

Catalog bounded context: products, SKUs, lifecycle, product events.

- **F-08 Product catalog API**: [CF-043](TASKS.md#cf-043) product-service: Product aggregate and catalog API (⬜ Not started)
- **F-09 Product events via CDC (vertical slice)**: [CF-044](TASKS.md#cf-044) product-service: ProductCreated through the outbox (⬜ Not started), [CF-045](TASKS.md#cf-045) Vertical slice: product created reaches Kafka via Debezium (⬜ Not started)

## CF-EPIC-05 — Customer Management

Customer profiles, addresses, contact events.

- **F-10 Customer profile**: [CF-050](TASKS.md#cf-050) customer-service: profile and address API (⬜ Not started), [CF-051](TASKS.md#cf-051) customer-service: CustomerRegistered / CustomerContactChanged (⬜ Not started)

## CF-EPIC-06 — Inventory Management

Stock, reservations, saga participation.

- **F-11 Stock projection and adjustments**: [CF-046](TASKS.md#cf-046) inventory-service: consume ProductCreated with inbox and DLT (⬜ Not started), [CF-047](TASKS.md#cf-047) inventory-service: stock adjustment API (⬜ Not started)
- **F-12 Reservations for the saga**: [CF-048](TASKS.md#cf-048) inventory-service: ReserveInventory / ReleaseInventory handlers (⬜ Not started), [CF-049](TASKS.md#cf-049) inventory-service: commit reservation on OrderConfirmed and expiry (⬜ Not started)

## CF-EPIC-07 — Pricing and Promotions

Prices, price lists, quotes, promotions.

- **F-13 Prices and quotes**: [CF-052](TASKS.md#cf-052) pricing-service: prices with ETag and ProductPriceChanged (⬜ Not started), [CF-053](TASKS.md#cf-053) pricing-service: price quote API (⬜ Not started)

## CF-EPIC-08 — Order Management

Order aggregate, order creation, order history, saga orchestration.

- **F-14 Order creation and history**: [CF-014](TASKS.md#cf-014) Decide cart ownership (⬜ Not started), [CF-055](TASKS.md#cf-055) order-service: create order (202, idempotency key) and OrderCreated (⬜ Not started), [CF-056](TASKS.md#cf-056) order-service: order history read model and GET APIs (⬜ Not started)
- **F-15 Order saga**: [CF-010](TASKS.md#cf-010) Order saga happy path end to end (⬜ Not started), [CF-011](TASKS.md#cf-011) Saga compensation and timeouts (⬜ Not started), [CF-059](TASKS.md#cf-059) Stuck-saga metric and saga status endpoint (⬜ Not started), [CF-062](TASKS.md#cf-062) Cancel a confirmed order (OrderCancelled flow) (⬜ Not started)

## CF-EPIC-09 — Payment Management

Provider adapter, authorization, void, refund.

- **F-16 Payment authorization and compensation**: [CF-016](TASKS.md#cf-016) Choose payment provider and sandbox; decide capture timing (⬜ Not started), [CF-057](TASKS.md#cf-057) payment-service: AuthorizePayment / VoidPayment with provider adapter (⬜ Not started)

## CF-EPIC-10 — Shipping Management

Shipments, carrier adapter, tracking.

- **F-17 Shipments**: [CF-060](TASKS.md#cf-060) shipping-service: shipment from OrderConfirmed (⬜ Not started), [CF-061](TASKS.md#cf-061) shipping-service: carrier adapter stub and tracking events (⬜ Not started)

## CF-EPIC-11 — Notification Processing

Customer notifications from order, payment and shipment events.

- **F-18 Notifications**: [CF-063](TASKS.md#cf-063) notification-service: email notifications for order lifecycle (⬜ Not started)

## CF-EPIC-12 — Event Driven Architecture

Contracts, schema registry, compatibility, outbox/CDC, DLT tooling.

- **F-19 Contracts and compatibility**: [CF-002](TASKS.md#cf-002) v1 Avro schemas for the core event catalogue (⬜ Not started), [CF-040](TASKS.md#cf-040) Shared contract compatibility testing (⬜ Not started)
- **F-20 Operability of the event pipeline**: [CF-023](TASKS.md#cf-023) Runbooks: slot growth, DLT replay, stuck saga, registry rejects schema (⬜ Not started), [CF-039](TASKS.md#cf-039) Expose Kafka Connect/Debezium metrics (⬜ Not started), [CF-042](TASKS.md#cf-042) DLT replay tool (⬜ Not started)

## CF-EPIC-13 — Admin Dashboard

Back-office UI through the admin BFF.

- **F-21 Admin access and management screens**: [CF-024](TASKS.md#cf-024) API gateway and admin BFF (⬜ Not started), [CF-064](TASKS.md#cf-064) admin-web: login and role-gated routes (⬜ Not started), [CF-066](TASKS.md#cf-066) admin-web: catalog and price management (⬜ Not started), [CF-067](TASKS.md#cf-067) admin-web: orders and saga status (⬜ Not started)

## CF-EPIC-14 — Storefront

Customer UI, catalog read model, checkout.

- **F-22 Catalog browsing**: [CF-015](TASKS.md#cf-015) Decide catalog read model ownership (⬜ Not started), [CF-072](TASKS.md#cf-072) Catalog read model (⬜ Not started), [CF-073](TASKS.md#cf-073) storefront-web: browse and product detail (⬜ Not started)
- **F-23 Checkout and order tracking**: [CF-074](TASKS.md#cf-074) storefront-web: checkout and order status (⬜ Not started), [CF-075](TASKS.md#cf-075) storefront-web: order history (⬜ Not started)

## CF-EPIC-15 — Testing and Quality

Architecture, contract, integration, E2E, performance and resilience tests.

- **F-24 Automated test layers**: [CF-017](TASKS.md#cf-017) Pact consumer/provider and broker (⬜ Not started), [CF-018](TASKS.md#cf-018) k6 baselines for browse and checkout (⬜ Not started), [CF-022](TASKS.md#cf-022) Architecture tests in every service (🟡 In progress), [CF-076](TASKS.md#cf-076) Cross-service integration suite (⬜ Not started), [CF-077](TASKS.md#cf-077) Cross-app Playwright journeys (⬜ Not started), [CF-078](TASKS.md#cf-078) Resilience scenario catalogue R1-R6 (⬜ Not started)

## CF-EPIC-16 — Observability

Tracing, metrics, logs, dashboards, alerts, SLOs.

- **F-25 Telemetry and SLOs**: [CF-012](TASKS.md#cf-012) OpenTelemetry in all services, trace through outbox (⬜ Not started), [CF-025](TASKS.md#cf-025) Define SLOs (⬜ Not started), [CF-079](TASKS.md#cf-079) Service dashboards and alert rules (⬜ Not started)

## CF-EPIC-17 — Security

Identity, authorization, secrets, scanning, threat models.

- **F-26 Identity and authorization**: [CF-065](TASKS.md#cf-065) Local identity provider (Keycloak) and roles (⬜ Not started), [CF-068](TASKS.md#cf-068) JWT resource server in every service (⬜ Not started), [CF-071](TASKS.md#cf-071) Threat model and security audit per release (⬜ Not started)
- **F-27 Supply chain and secrets**: [CF-070](TASKS.md#cf-070) Secret and dependency scanning in CI (⬜ Not started)

## CF-EPIC-18 — Production Readiness

CI/CD, Helm, Kubernetes, Terraform, DR, retention.

- **F-28 CI/CD per component**: [CF-020](TASKS.md#cf-020) Reusable CI workflows per language (⛔ Blocked), [CF-080](TASKS.md#cf-080) Dependency-aware CI triggering (⬜ Not started), [CF-084](TASKS.md#cf-084) product-service: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-085](TASKS.md#cf-085) order-service: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-086](TASKS.md#cf-086) payment-service: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-087](TASKS.md#cf-087) customer-service: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-088](TASKS.md#cf-088) pricing-service: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-089](TASKS.md#cf-089) inventory-service: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-090](TASKS.md#cf-090) shipping-service: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-091](TASKS.md#cf-091) notification-service: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-092](TASKS.md#cf-092) admin-web: own CI pipeline, image publish and staged deployment (⬜ Not started), [CF-093](TASKS.md#cf-093) storefront-web: own CI pipeline, image publish and staged deployment (⬜ Not started)
- **F-29 Cluster and cloud**: [CF-004](TASKS.md#cf-004) Choose cloud provider and Terraform state backend (⬜ Not started), [CF-019](TASKS.md#cf-019) Helm chart template and per-service values (⬜ Not started), [CF-081](TASKS.md#cf-081) Kubernetes base: namespaces, network policies, quotas (⬜ Not started), [CF-082](TASKS.md#cf-082) Terraform baseline (⬜ Not started), [CF-083](TASKS.md#cf-083) Production Debezium: heartbeats, failover slots, Connect HA (⬜ Not started)
- **F-30 Operations and data governance**: [CF-026](TASKS.md#cf-026) Data retention with legal input (⬜ Not started), [CF-027](TASKS.md#cf-027) RPO/RTO, backups and restore drills (⬜ Not started)
