# Service definitions

Status: **buildable scaffolds** for every component below (health/readiness, tests,
Dockerfile — see `../service-catalog.md`); responsibilities, APIs and events are **planned**. Languages: ADR-0003. Ports
and databases: [service-catalog.md](service-catalog.md). Events:
[../event-catalog/event-catalog.md](../event-catalog/event-catalog.md).

Each definition lists: responsibility, owned data, APIs (planned), events, dependencies,
scaling notes and open questions.

---

## 1. Product Service — Kotlin + Spring Boot

- **Path / DB / port:** `services/product-service` · `product_db` · 8081
- **Responsibility:** products, SKUs, categories, attributes, lifecycle (draft → active →
  discontinued).
- **Owns:** product, sku, category, attribute values; outbox.
- **APIs (planned):** `GET/POST /v1/products`, `GET/PATCH /v1/products/{id}` (admin writes,
  public reads).
- **Publishes:** ProductCreated, ProductUpdated, ProductDiscontinued.
- **Consumes:** —
- **Depends on:** nothing synchronously.
- **Scaling:** read-heavy; Redis cache for catalog reads.
- **Open:** whether it hosts the catalog read model (CF-015).

## 2. Order Service — Kotlin + Spring Boot

- **Path / DB / port:** `services/order-service` · `order_db` · 8082
- **Responsibility:** order aggregate, order saga orchestration (ADR-0009), order history
  read model for customers and staff.
- **Owns:** customer_order, order_line, saga_instance, idempotency_key; outbox, inbox.
- **APIs (planned):** `POST /v1/orders` (202, idempotency key), `GET /v1/orders/{id}`,
  `GET /v1/orders?customerId=…` (cursor pagination), `POST /v1/orders/{id}/cancellation`.
- **Publishes:** OrderCreated, OrderConfirmed, OrderRejected, OrderCancelled; commands
  ReserveInventory, ReleaseInventory, AuthorizePayment, VoidPayment.
- **Consumes:** StockReserved, StockReservationFailed, StockReleased, PaymentAuthorized,
  PaymentFailed, PaymentVoided, PaymentRefunded, ShipmentCreated, ShipmentDispatched,
  ShipmentDelivered.
- **Depends on (sync):** pricing-service (quote), customer-service (validation).
- **Scaling:** stateless API; saga throughput bounded by partitions of reply topics.
- **Open:** cart ownership (CF-014).

## 3. Inventory Service — Go

- **Path / DB / port:** `services/inventory-service` · `inventory_db` · 8083
- **Responsibility:** stock per SKU (and location later), reservations with expiry, no
  oversell.
- **Owns:** stock_item, reservation, product projection; outbox, inbox.
- **APIs (planned):** `GET /v1/stock/{sku}`, `POST /v1/stock/{sku}/adjustments` (admin).
- **Publishes:** StockReserved, StockReservationFailed, StockReleased, StockLevelChanged.
- **Consumes:** commands ReserveInventory, ReleaseInventory; ProductCreated,
  ProductDiscontinued, OrderConfirmed (commit reservation), OrderCancelled.
- **Depends on (sync):** none.
- **Scaling:** contention on hot SKUs; conditional atomic updates; per-SKU ordering via
  partition key.
- **Open:** multi-location stock; reservation expiry duration (not defined).

## 4. Payment Service — Kotlin + Spring Boot

- **Path / DB / port:** `services/payment-service` · `payment_db` · 8084
- **Responsibility:** authorize, void, capture and refund through a provider adapter (ACL).
- **Owns:** payment, payment_attempt, provider references; outbox, inbox.
- **APIs (planned):** provider webhook endpoint; admin read of payments.
- **Publishes:** PaymentAuthorized, PaymentFailed, PaymentVoided, PaymentRefunded.
- **Consumes:** commands AuthorizePayment, VoidPayment; OrderCancelled.
- **Depends on:** payment provider (external).
- **Scaling:** provider latency dominates; idempotency keys towards the provider.
- **Open:** provider (CF-016); capture timing (at confirmation or at shipment) — not decided.

## 5. Customer Service — Kotlin + Spring Boot

- **Path / DB / port:** `services/customer-service` · `customer_db` · 8085
- **Responsibility:** customer profile, addresses, contact preferences (identity itself is
  in the identity provider).
- **Owns:** customer, address; outbox.
- **APIs (planned):** `GET/PATCH /v1/customers/me`, address management.
- **Publishes:** CustomerRegistered, CustomerContactChanged.
- **Consumes:** —
- **Scaling:** low write volume.
- **Open:** link between IdP subject and customer record (on first sign-in or registration
  event from the IdP).

## 6. Pricing Service — Kotlin + Spring Boot

- **Path / DB / port:** `services/pricing-service` · `pricing_db` · 8086
- **Responsibility:** base prices, price lists, promotions, price quotes.
- **Owns:** price, price_list, promotion, product projection; outbox, inbox.
- **APIs (planned):** `POST /v1/quotes` (order-service, storefront), `PUT /v1/prices/{sku}`
  (admin, ETag).
- **Publishes:** ProductPriceChanged.
- **Consumes:** ProductCreated, ProductDiscontinued.
- **Scaling:** quote endpoint is on the checkout path; Redis cache for lookups.
- **Open:** promotion model scope; quote validity period.

## 7. Shipping Service — Go

- **Path / DB / port:** `services/shipping-service` · `shipping_db` · 8087
- **Responsibility:** shipments, carrier integration (ACL), tracking status.
- **Owns:** shipment, tracking_event; outbox, inbox.
- **APIs (planned):** carrier webhook endpoints; admin read of shipments.
- **Publishes:** ShipmentCreated, ShipmentDispatched, ShipmentDelivered.
- **Consumes:** OrderConfirmed, OrderCancelled.
- **Depends on:** carrier APIs (external).
- **Open:** carrier selection.

## 8. Notification Service — Go

- **Path / DB / port:** `services/notification-service` · `notification_db` · 8088
- **Responsibility:** templates, channel delivery (email first), delivery log.
- **Owns:** notification, template, delivery_log, contact projection; inbox.
- **APIs (planned):** admin template management.
- **Publishes:** — (delivery status events not planned yet).
- **Consumes:** CustomerRegistered, CustomerContactChanged, OrderCreated, OrderConfirmed,
  OrderRejected, OrderCancelled, PaymentFailed, PaymentRefunded, ShipmentDispatched,
  ShipmentDelivered.
- **Depends on:** email provider (external).
- **Scaling:** I/O-bound fan-out; order-independent handling allows non-blocking retries.

## 9. Admin Web — React + TypeScript

- **Path / port:** `apps/admin-web` · 5173
- **Users:** staff with roles per context (catalog, pricing, inventory, order, shipping).
- **Talks to:** admin BFF (ADR-0010, planned) → service APIs.
- **Features:** catalog, prices and promotions, stock adjustments, order and shipment
  management, saga status view.
- **Open:** role model in the IdP.

## 10. Storefront Web — React + TypeScript

- **Path / port:** `apps/storefront-web` · 5174
- **Users:** customers (anonymous browsing, signed-in checkout).
- **Talks to:** API gateway → product/catalog read model, pricing, customer, order APIs.
- **Features:** browse, product detail, cart (owner open, CF-014), checkout, order
  history, account.
- **Open:** server-side rendering for SEO (not decided).
