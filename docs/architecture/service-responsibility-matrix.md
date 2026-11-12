# Service responsibility matrix

Status: **planned**. Responsibilities are assigned; no service is implemented.

## Ownership of business capabilities

| Capability | Owner (single writer) | Contributors (read via events/API) |
|---|---|---|
| Products, SKUs, categories, attributes, lifecycle | product-service | pricing, inventory, catalog read model, admin-web |
| Base prices, price lists, promotions, price quotes | pricing-service | order (quote at checkout), catalog read model |
| Customer profile, addresses, contact preferences | customer-service | order, notification |
| Orders, order lines, order status, saga state, order history | order-service | storefront, admin-web, notification |
| Stock levels, reservations | inventory-service | order (saga), catalog read model |
| Payment authorization, void, capture, refund | payment-service | order (saga) |
| Shipments, carrier integration, tracking | shipping-service | order, notification |
| Notification templates, delivery, delivery log | notification-service | — |
| Catalog read model (product + price + availability) | **Open** (CF-015) | storefront |
| Cart | **Open** (CF-014) | storefront |

## RACI for cross-cutting flows

R = does the work, A = accountable for correctness, C = consulted (contract), I = informed (consumes events).

| Flow | product | pricing | customer | order | inventory | payment | shipping | notification |
|---|---|---|---|---|---|---|---|---|
| Publish product | A/R | I | | | I | | | |
| Change price | C | A/R | | | | | | |
| Place order (saga) | | C (quote) | C | A/R | R | R | | I |
| Confirm order | | | | A/R | I | | I | I |
| Cancel confirmed order | | | | A/R | R (release) | R (refund) | R (stop) | I |
| Ship and deliver | | | | I | | | A/R | I |
| Notify customer | | | C | I | | I | I | A/R |

## Data ownership summary

| Service | Database | Main tables (planned) | Redis |
|---|---|---|---|
| product-service | `product_db` | product, sku, category, outbox | catalog cache |
| pricing-service | `pricing_db` | price, price_list, promotion, outbox, inbox | price lookup cache |
| customer-service | `customer_db` | customer, address, outbox | — |
| order-service | `order_db` | customer_order, order_line, saga_instance, idempotency_key, outbox, inbox | — |
| inventory-service | `inventory_db` | stock_item, reservation, product_projection, outbox, inbox | — |
| payment-service | `payment_db` | payment, payment_attempt, outbox, inbox | — |
| shipping-service | `shipping_db` | shipment, tracking_event, outbox, inbox | — |
| notification-service | `notification_db` | notification, template, delivery_log, inbox | — |

Details: [database-ownership.md](database-ownership.md). Per-service definitions:
[service-definitions.md](service-definitions.md).
