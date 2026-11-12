# storefront-web — Claude Code guide

Read the root `CLAUDE.md` first. This folder is an independently built and deployed
frontend inside the CommerceFlow monorepo.

## Purpose

Customers. Browse and search catalog, product detail, cart, checkout, order history, account.

## Backend APIs used

product (catalog read model), pricing, customer, order services, over HTTP only. The app never talks to Kafka or databases, and never
imports code from `services/` or the other app.

## Independence

Own `package.json` and lockfile in this folder. API types are generated from
`contracts/openapi/`, not shared with the other app.

## Planned layout

```
src/
  app/            routing, providers, layout
  features/<x>/   one folder per feature: components, hooks, API client
  shared/         design-system components, utilities (local to this app)
  api/            typed HTTP clients generated from contracts/openapi
tests/
  unit/           Vitest + React Testing Library
  e2e/            Playwright tests for this app only (cross-app flows: tests/e2e)
pacts/            Pact consumer contracts
```

## Rules

- TypeScript `strict` mode. No `any` in API types.
- Every backend call goes through `src/api/`, so Pact tests cover it.
- Propagate W3C `traceparent` on API requests (OpenTelemetry web SDK).
- Run type check, unit tests and relevant Playwright tests before reporting that
  something works.

## Status

Scaffold only — no code yet.
