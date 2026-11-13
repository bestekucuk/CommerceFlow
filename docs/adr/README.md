# Architecture Decision Records

New ADRs start as `Proposed`. Only the project owner moves an ADR to `Accepted`.
Use `0000-template.md` (or `/architecture-decision-records`).

| ADR | Title | Status |
|---|---|---|
| [0001](0001-polyrepo-strategy.md) | Polyrepo with a platform repository | Superseded by 0004 |
| [0002](0002-event-integration-outbox-cdc.md) | Event integration via transactional outbox and Debezium CDC | Superseded by 0006, 0007 |
| [0003](0003-language-per-service.md) | Language per service (Kotlin and Go technology split) | Accepted |
| [0004](0004-modular-monorepo.md) | Modular monorepo with independently deployable services | Accepted |
| [0005](0005-database-per-service.md) | Database per service | Proposed |
| [0006](0006-transactional-outbox.md) | Transactional outbox for publishing events and commands | Proposed |
| [0007](0007-debezium-cdc.md) | Debezium CDC relays outbox rows to Kafka | Proposed |
| [0008](0008-kafka-event-backbone.md) | Apache Kafka as the event backbone | Proposed |
| [0009](0009-saga-orchestration.md) | Order saga orchestrated by order-service | Proposed |
| [0010](0010-api-gateway-and-admin-bff.md) | API gateway for client traffic and a BFF for admin-web | Proposed |
| [0011](0011-independent-service-deployment.md) | Independent build, release and deployment per service | Proposed |
| [0012](0012-mvp-scope-cart-and-guest-checkout.md) | MVP scope: browser-side cart, guest checkout, no login yet | Accepted (MVP) |
| [0013](0013-fake-payment-provider-for-mvp.md) | Fake payment provider adapter for the MVP | Accepted (MVP) |

## By topic

| Topic | ADR |
|---|---|
| Modular monorepo | 0004 |
| Kotlin and Go technology split | 0003 |
| Database per service | 0005 |
| Transactional outbox | 0006 |
| Debezium CDC | 0007 |
| Kafka as event backbone | 0008 |
| Saga orchestration | 0009 |
| API gateway and admin BFF | 0010 |
| Independent service deployment | 0011 |
| MVP scope: cart, guest checkout, no login | 0012 |
| Payment provider for the MVP | 0013 |
