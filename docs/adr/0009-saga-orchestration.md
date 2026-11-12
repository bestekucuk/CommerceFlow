# 0009. Order saga orchestrated by order-service

- Status: Proposed
- Date: 2026-11-12
- Deciders: project owner, commerce-architect
- Affected areas: `services/order-service`, `services/inventory-service`, `services/payment-service`, `services/shipping-service`, `contracts/events`

## Context

Placing an order needs stock reservation (inventory) and payment authorization (payment)
before confirmation, and compensation when a step fails. These services own separate
databases (ADR-0005), so a distributed transaction is not possible.

## Decision

- The order placement process is an **orchestrated saga** owned by order-service.
- order-service persists saga state (`saga_instance`) in `order_db` and sends commands
  (`ReserveInventory`, `ReleaseInventory`, `AuthorizePayment`, `VoidPayment`) through its
  outbox; participants reply with events (`StockReserved`, `PaymentAuthorized`, …).
- Every waiting state has a deadline; a timeout triggers the same compensation as a failure.
- Order confirmation is the pivot: after `OrderConfirmed` no step is compensated; later
  cancellation is a separate flow (`OrderCancelled` → release/refund/stop shipment).
- Downstream reactions that do not need coordination (shipment creation, notifications)
  are **choreographed** from `OrderConfirmed`/`OrderCancelled`.

Flows: `docs/architecture/communication-patterns.md`.

## Alternatives considered

- **Full choreography** — no central coordinator; the overall flow and its timeouts become
  implicit across services and hard to change or observe.
- **Workflow engine (e.g. Temporal, Camunda)** — durable timers and visibility built in; adds
  a platform dependency and a second programming model before the need is proven.

## Consequences

- order-service is the single place to read and change the order flow.
- Participants must be idempotent and must reply even when there is nothing to compensate.
- Saga state must be observable (stuck-saga metric, admin view, runbook).
