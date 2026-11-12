# product-service

Catalog bounded context of CommerceFlow. Products, SKUs, categories, attributes and product lifecycle.

## Status

Scaffold only. No source code, build files or Dockerfile exist yet. Nothing builds or
runs.

## Stack

Kotlin, Spring Boot, PostgreSQL (`product_db`), Kafka, JUnit 5, Testcontainers

## Integration

- Publishes: ProductCreated, ProductUpdated, ProductDiscontinued
- Consumes: —
- Redis: Catalog read model cache (CQRS read side, see CF-015)

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
