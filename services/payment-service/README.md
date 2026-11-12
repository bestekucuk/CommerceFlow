# payment-service

Payments bounded context of CommerceFlow. Payment authorization, capture, void and refund through a provider adapter (provider not chosen, CF-016).

## Status

Scaffold only. No source code, build files or Dockerfile exist yet. Nothing builds or
runs.

## Stack

Kotlin, Spring Boot, PostgreSQL (`payment_db`), Kafka, JUnit 5, Testcontainers

## Integration

- Publishes: PaymentAuthorized, PaymentFailed, PaymentRefunded
- Consumes: Commands AuthorizePayment, VoidPayment; OrderCancelled
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
