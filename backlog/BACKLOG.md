# Engineering Backlog

IDs are referenced in commit messages. Tags: `decision`, `platform`, `service`, `web`,
`test`, `observability`. "Area" is the top-level folder(s) the item touches.

## Now

| ID | Item | Area | Tags |
|---|---|---|---|
| CF-001 | Review ADR-0002; ADR-0003 and ADR-0004 are accepted | docs | decision |
| CF-002 | Write v1 Avro schemas for the event catalog, including `EventMetadata` | contracts | platform |
| CF-003 | Choose contract codegen tooling for Kotlin (Gradle Avro plugin) and Go | contracts, services | decision |
| CF-005 | Root `docker-compose.yml`: Kafka, Schema Registry, Connect/Debezium, PostgreSQL per service, Redis | infrastructure | platform |
| CF-021 | Monorepo build tooling: independent build per service (own Gradle wrapper / go.mod / package.json) plus root scripts that detect affected services | scripts, services, apps | platform |
| CF-006 | Scaffold order-service (Kotlin) with outbox, inbox, Flyway, health, OTel | services/order-service | service |
| CF-007 | Scaffold inventory-service (Go) with outbox, inbox, migrations, health, OTel | services/inventory-service | service |

## Next

| ID | Item | Area | Tags |
|---|---|---|---|
| CF-004 | Choose cloud provider, Terraform location and state backend | infrastructure | decision |
| CF-008 | Scaffold remaining Kotlin services from the order-service conventions | product, payment, customer, pricing | service |
| CF-009 | Scaffold remaining Go services from the inventory-service conventions | shipping, notification | service |
| CF-010 | Implement order saga happy path end to end | order, inventory, payment, tests/integration | service |
| CF-011 | Saga compensation and timeouts with Toxiproxy tests | order, inventory, payment, tests/resilience | test |
| CF-012 | Monitoring stack in Compose; trace across HTTP → outbox → Kafka → consumer | infrastructure/monitoring, services | observability |
| CF-013 | Scaffold storefront-web and admin-web (Vite, React, TypeScript, Playwright) | apps | web |
| CF-014 | Decide cart ownership (order-service vs dedicated context vs client-side) | docs | decision |
| CF-015 | Decide location of catalog read model for storefront (CQRS) | docs | decision |
| CF-016 | Choose payment provider adapter and sandbox | services/payment-service | decision |
| CF-022 | Architecture tests that fail the build on cross-service imports or database access | services, tests | test |

## Later

| ID | Item | Area | Tags |
|---|---|---|---|
| CF-017 | Pact contracts between web apps and services | apps, services, tests/contract | test |
| CF-018 | k6 load test for checkout | tests/performance | test |
| CF-019 | Helm chart per service | infrastructure/kubernetes | platform |
| CF-020 | CI pipeline per service with path filters (service folder + contracts it uses) | all | platform |
| CF-023 | Runbooks: Debezium replication slot growth, DLT replay, saga stuck in PENDING | docs/runbooks | platform |
