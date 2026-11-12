# inventory-service

Inventory bounded context of CommerceFlow. Stock levels per SKU and location, reservations with expiry.

## Status

Scaffold only. No source code, build files or Dockerfile exist yet. Nothing builds or
runs.

## Stack

Go, PostgreSQL (`inventory_db`), Kafka, Go testing, Testcontainers for Go

## Integration

- Publishes: InventoryReserved, InventoryReservationFailed, InventoryReleased, StockLevelChanged
- Consumes: Commands ReserveInventory, ReleaseInventory; ProductCreated, ProductDiscontinued, OrderCancelled
- Redis: —

Contracts: `contracts/events/`. Event catalog: `docs/event-catalog/README.md`.
