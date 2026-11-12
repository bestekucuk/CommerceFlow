# notification-service

Notification bounded context of CommerceFlow. Notification templates, channel delivery (email first) and delivery log.

## Status

Scaffold only. No source code, build files or Dockerfile exist yet. Nothing builds or
runs.

## Stack

Go, PostgreSQL (`notification_db`), Kafka, Go testing, Testcontainers for Go

## Integration

- Publishes: —
- Consumes: CustomerRegistered, CustomerContactChanged, OrderPlaced, OrderConfirmed, OrderRejected, OrderCancelled, PaymentFailed, PaymentRefunded, ShipmentDispatched, ShipmentDelivered
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
