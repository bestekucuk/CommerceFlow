# admin-web — Claude Code guide

Read the root `CLAUDE.md` first. This folder is an independently built and deployed
frontend inside the CommerceFlow monorepo.

## Purpose

Staff (back office). Catalog management, pricing and promotions, inventory adjustments, order and shipment management.

## Backend APIs used

product, pricing, inventory, order, shipping, customer services, over HTTP only. The app never talks to Kafka or databases, and never
imports code from `services/` or the other app.

## Independence

Own `package.json` and lockfile in this folder. API types are generated from
`contracts/openapi/`, not shared with the other app.

## Layout

```
src/
  app/          App root, routing and providers (later)
  features/     one folder per feature
  components/   app-local UI components (AppShell)
  services/     configuration and API clients (generated from contracts/openapi later)
  hooks/        app-local hooks
  types/        shared TypeScript types for this app
tests/
  unit/         Vitest + React Testing Library
  e2e/          Playwright (app-local; cross-app journeys: tests/e2e at repo root)
vite.config.ts, playwright.config.ts, tsconfig.json (strict)
Dockerfile, nginx.conf   static build served by nginx (healthz/readyz)
```

## Rules

- TypeScript `strict` mode. No `any` in API types.
- Every backend call goes through `src/services/`, so Pact tests cover it.
- Propagate W3C `traceparent` on API requests (OpenTelemetry web SDK).
- Run type check, unit tests and relevant Playwright tests before reporting that
  something works.

## Status

Buildable scaffold — app shell, unit and E2E smoke tests. No features yet.
