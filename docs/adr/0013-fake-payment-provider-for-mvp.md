# 0013. Fake payment provider adapter for the MVP

- Status: Accepted (for the MVP; CF-016 still chooses the real provider)
- Date: 2026-11-12
- Deciders: project owner (MVP scope chosen 2026-11-12), commerce-architect
- Affected areas: `services/payment-service`

## Context

The order saga needs payment authorization and void (CF-057). Choosing a real provider,
getting sandbox access and deciding capture timing is CF-016, which needs business input.
The MVP must still show the complete saga, including the failure and compensation paths.

## Decision

- payment-service talks to providers through a port (`PaymentProvider`:
  `authorize(orderId, amount, idempotencyKey)`, `void(authorizationId)`), as planned.
- The MVP ships one adapter, **`FakePaymentProvider`**, selected by configuration
  (`PAYMENT_PROVIDER=fake`). It never handles card data: the storefront sends no card
  fields at all.
- Deterministic outcomes so tests and demos can drive both paths:
  - amount ≤ 10 000.00 in the order currency → **authorized**
  - amount > 10 000.00 → **declined** (`PaymentFailed`, reason `DECLINED_LIMIT`)
- Authorization is idempotent per idempotency key (the saga's command id); void of an
  unknown or already-voided authorization succeeds (participants must reply even when
  there is nothing to compensate, ADR-0009).

## Alternatives considered

- **Provider sandbox now** — realistic, but blocks the MVP on account setup and a business
  decision (CF-016).
- **Random failures** — exercises compensation but makes tests and demos unpredictable.

## Consequences

- The saga, compensation and observability can be built and verified end to end without
  external accounts.
- The fake adapter must never be selectable in a shared or production environment; the
  service refuses to start with `PAYMENT_PROVIDER=fake` unless the profile is `local`
  or `test`.
- Follow-up: CF-016 (real provider, sandbox, capture timing) adds a second adapter behind
  the same port.
