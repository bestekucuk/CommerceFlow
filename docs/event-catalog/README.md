# Event Catalog

Status: **planned**. No schemas exist yet; this lists the intended events so contracts
can be written next. Topic naming: see `contracts/events/README.md`.

## Facts (events)

| Event | Topic | Producer | Consumers |
|---|---|---|---|
| ProductCreated | `cf.product.events.v1` | product | pricing, inventory, catalog read model |
| ProductUpdated | `cf.product.events.v1` | product | catalog read model |
| ProductDiscontinued | `cf.product.events.v1` | product | pricing, inventory, catalog read model |
| PriceChanged | `cf.price.events.v1` | pricing | catalog read model |
| CustomerRegistered | `cf.customer.events.v1` | customer | notification |
| CustomerContactChanged | `cf.customer.events.v1` | customer | notification |
| OrderPlaced | `cf.order.events.v1` | order | notification |
| OrderConfirmed | `cf.order.events.v1` | order | shipping, notification |
| OrderRejected | `cf.order.events.v1` | order | notification |
| OrderCancelled | `cf.order.events.v1` | order | inventory, payment, shipping, notification |
| InventoryReserved | `cf.inventory.events.v1` | inventory | order |
| InventoryReservationFailed | `cf.inventory.events.v1` | inventory | order |
| InventoryReleased | `cf.inventory.events.v1` | inventory | order |
| StockLevelChanged | `cf.inventory.events.v1` | inventory | catalog read model |
| PaymentAuthorized | `cf.payment.events.v1` | payment | order |
| PaymentFailed | `cf.payment.events.v1` | payment | order, notification |
| PaymentRefunded | `cf.payment.events.v1` | payment | order, notification |
| ShipmentCreated | `cf.shipment.events.v1` | shipping | order |
| ShipmentDispatched | `cf.shipment.events.v1` | shipping | order, notification |
| ShipmentDelivered | `cf.shipment.events.v1` | shipping | order, notification |

## Saga commands

| Command | Topic | Sender | Handler |
|---|---|---|---|
| ReserveInventory | `cf.inventory.commands.v1` | order | inventory |
| ReleaseInventory | `cf.inventory.commands.v1` | order | inventory |
| AuthorizePayment | `cf.payment.commands.v1` | order | payment |
| VoidPayment | `cf.payment.commands.v1` | order | payment |
