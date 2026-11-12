# shipping-service

Fulfilment bounded context of CommerceFlow. Shipments, carrier integration adapter and tracking status.

## Status

Scaffold only. No source code, build files or Dockerfile exist yet. Nothing builds or
runs.

## Stack

Go, PostgreSQL (`shipping_db`), Kafka, Go testing, Testcontainers for Go

## Integration

- Publishes: ShipmentCreated, ShipmentDispatched, ShipmentDelivered
- Consumes: OrderConfirmed, OrderCancelled
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
