# 0003. Language per service

- Status: Accepted (2026-11-12, decided by the project owner; revises the earlier proposal)
- Date: 2026-11-12
- Affected areas: `services/*`, `apps/*`

## Context

The stack allows Kotlin/Spring Boot and Go for backends, React/TypeScript for frontends.
Each service needs exactly one language.

## Decision

| Service | Language |
|---|---|
| product-service | Kotlin + Spring Boot |
| order-service | Kotlin + Spring Boot |
| payment-service | Kotlin + Spring Boot |
| customer-service | Kotlin + Spring Boot |
| pricing-service | Kotlin + Spring Boot |
| inventory-service | Go |
| shipping-service | Go |
| notification-service | Go |
| admin-web | React + TypeScript |
| storefront-web | React + TypeScript |

Kotlin/Spring Boot serves the services with rich domain models and transactional
workflows (catalog, ordering and the saga orchestrator, payments, customers, pricing
rules and promotions). Go serves services with narrow models and high-throughput or
I/O-bound work: reservation handling under checkout load, carrier adapters, and message
fan-out.

The earlier proposal had inventory in Kotlin and pricing in Go; the project owner
swapped them.

## Alternatives considered

- Single language for all services — simpler tooling; loses the chance to validate both
  stacks and the polyglot contract story.

## Consequences

- Outbox/inbox, tracing and Kafka conventions must be implemented in both languages.
- The saga's two synchronous participants (inventory in Go, payment in Kotlin) exercise
  both stacks early, which surfaces contract and tracing gaps sooner.
- Contracts must be consumable from both (Avro code generation for Kotlin and Go, CF-003).
