# customer-service

Customer bounded context of CommerceFlow. Customer profiles, addresses and contact preferences.

## Status

Scaffold only. No source code, build files or Dockerfile exist yet. Nothing builds or
runs.

## Stack

Kotlin, Spring Boot, PostgreSQL (`customer_db`), Kafka, JUnit 5, Testcontainers

## Integration

- Publishes: CustomerRegistered, CustomerContactChanged
- Consumes: —
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
