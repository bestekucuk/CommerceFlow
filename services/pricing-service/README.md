# pricing-service

Pricing bounded context of CommerceFlow. Base prices, price lists, promotions and price quotes.

## Status

Scaffold only. No source code, build files or Dockerfile exist yet. Nothing builds or
runs.

## Stack

Kotlin, Spring Boot, PostgreSQL (`pricing_db`), Kafka, JUnit 5, Testcontainers

## Integration

- Publishes: PriceChanged
- Consumes: ProductCreated, ProductDiscontinued
- Redis: Price lookup cache

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
