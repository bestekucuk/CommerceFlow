# order-service

Ordering bounded context of CommerceFlow. Order aggregate, order saga orchestration and order history read model.

## Status

Scaffold only. No source code, build files or Dockerfile exist yet. Nothing builds or
runs.

## Stack

Kotlin, Spring Boot, PostgreSQL (`order_db`), Kafka, JUnit 5, Testcontainers

## Integration

- Publishes: OrderPlaced, OrderConfirmed, OrderRejected, OrderCancelled; commands ReserveInventory, ReleaseInventory, AuthorizePayment, VoidPayment
- Consumes: InventoryReserved, InventoryReservationFailed, InventoryReleased, PaymentAuthorized, PaymentFailed, PaymentRefunded, ShipmentCreated, ShipmentDispatched, ShipmentDelivered
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
