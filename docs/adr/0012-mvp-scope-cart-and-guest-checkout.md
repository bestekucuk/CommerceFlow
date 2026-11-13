# 0012. MVP scope: browser-side cart, guest checkout, no login yet

- Status: Accepted (for the MVP; revisit before any shared environment)
- Date: 2026-11-12
- Deciders: project owner (MVP scope chosen 2026-11-12), commerce-architect
- Affected areas: `apps/storefront-web`, `apps/admin-web`, `services/order-service`,
  `services/pricing-service`, `services/product-service`, `services/inventory-service`

## Context

The owner chose a first runnable version (MVP) with the basic sales flow, run locally:
staff enter products, prices and stock; customers browse, collect items, check out and
follow the order status; the order saga (ADR-0009) reserves stock, authorizes payment and
confirms or compensates.

Three questions in the backlog block that flow: who owns the cart (CF-014), how customers
are identified at checkout (CF-050/CF-065), and how the web apps reach the services before
the gateway and admin BFF exist (CF-024, ADR-0010).

## Decision

1. **Cart lives in the browser** (storefront-web, `localStorage`) for the MVP. It holds SKU
   and quantity only. Prices are never trusted from the cart: at checkout the storefront
   asks pricing-service for a **quote** (CF-053), and order-service validates that quote.
2. **Guest checkout.** The order carries the buyer's e-mail and shipping address as order
   data. No customer account is required; customer-service is not on the MVP path.
3. **No login in the MVP.** admin-web and the service APIs are unauthenticated and only
   reachable on `localhost`. OpenAPI specs keep declaring `security: []` explicitly so
   the gap stays visible. Login comes with CF-065/CF-068.
4. **Apps call service APIs directly** through their own reverse proxy (Vite dev proxy,
   nginx in the image) under path prefixes such as `/api/product/`. No browser code
   addresses a service host. The gateway/BFF (ADR-0010, CF-024) replaces the proxy later
   without changing app code beyond the base path.

## Alternatives considered

- **Cart in order-service** (a DRAFT order) — survives device changes, but mixes a
  high-churn, anonymous object into the order aggregate and its saga; not needed for a
  local MVP.
- **Dedicated cart service** — the most scalable option; one more service, database and
  pipeline before there is any traffic to justify it.
- **Login first (Keycloak)** — the right end state; it would delay the first working flow by
  the whole identity phase.

## Consequences

- The cart is lost when the browser storage is cleared and does not follow the customer
  between devices. Acceptable for the MVP; revisit with CF-014 when accounts exist.
- Anyone on the machine can call the admin APIs. The MVP must never be exposed beyond
  `localhost`; CF-065, CF-068 and CF-024 are prerequisites for any shared environment.
- Guest orders have no customer id; order-service stores `customer_email` and the
  address. When accounts arrive, orders gain an optional `customerId` (additive change).
- Follow-up: CF-014 remains open for the post-MVP cart decision; CF-024 removes the
  per-app proxies.
