# Service Catalog

Status: **planned**. Ports and names are proposals for local development. Languages are
decided in ADR-0003.

| Path | Bounded context | Language | Database | Redis | Local port |
|---|---|---|---|---|---|
| `services/product-service` | Catalog | Kotlin / Spring Boot | `product_db` | catalog read model cache | 8081 |
| `services/order-service` | Ordering | Kotlin / Spring Boot | `order_db` | — | 8082 |
| `services/inventory-service` | Inventory | Go | `inventory_db` | — | 8083 |
| `services/payment-service` | Payments | Kotlin / Spring Boot | `payment_db` | — | 8084 |
| `services/customer-service` | Customer | Kotlin / Spring Boot | `customer_db` | — | 8085 |
| `services/pricing-service` | Pricing | Kotlin / Spring Boot | `pricing_db` | price lookup cache | 8086 |
| `services/shipping-service` | Fulfilment | Go | `shipping_db` | — | 8087 |
| `services/notification-service` | Notification | Go | `notification_db` | — | 8088 |
| `apps/admin-web` | Back office UI | React / TypeScript | — | — | 5173 |
| `apps/storefront-web` | Storefront UI | React / TypeScript | — | — | 5174 |

## Responsibilities

- **product-service**: products, variants/SKUs, categories, attributes, lifecycle
  (draft, active, discontinued).
- **order-service**: order aggregate, order saga orchestration, order history read model.
- **inventory-service**: stock levels per SKU and location, reservations with expiry.
- **payment-service**: payment authorization, capture, void and refund through a payment
  provider adapter (provider not chosen).
- **customer-service**: customer profiles, addresses, contact preferences.
- **pricing-service**: base prices, price lists, promotions, price quotes.
- **shipping-service**: shipments, carrier integration (adapter), tracking status.
- **notification-service**: notification templates, channel delivery (email first),
  delivery log.
- **admin-web**: catalog, pricing, inventory and order management for staff.
- **storefront-web**: browse, cart, checkout, order history for customers.
