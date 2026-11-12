---
name: create-api
description: Workflow to design and implement a versioned CommerceFlow REST API - OpenAPI-first spec in contracts/openapi, compatibility classification, implementation in the owning Kotlin or Go service with problem details, security and idempotency, provider tests, consumer client regeneration and Pact updates. Use when an endpoint is added or changed.
argument-hint: "<service> <METHOD /v1/path> <purpose>"
---

# create-api

## Purpose

Add or change an HTTP endpoint so that its contract is documented first, its consumers
stay compatible, and the implementation follows CommerceFlow API conventions.

## Invocation

```text
/create-api order-service "GET /v1/orders/{orderId}" "Customer reads own order with saga status"
```

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Owning service | yes | folder under `services/` |
| Method and path | yes | major version prefix `/v1` (or `/v2` for breaking) |
| Purpose / consumers | yes | which app or service calls it |
| Auth requirements | no | default: authenticated, owner-or-admin |

## Required context

`contracts/openapi/<service>.v1.yaml` (create if missing), the service's `CLAUDE.md`,
`docs/architecture/service-catalog.md`, consuming app's `CLAUDE.md`.

## Relevant agents

`kotlin-backend-engineer` / `golang-backend-engineer` (spec + implementation),
`frontend-engineer` (client + Pact), `test-engineer` (provider verification wiring),
`security-reviewer` (public or sensitive endpoints), `code-reviewer`.

## Relevant skills

`rest-api-design`, `secure-backend-development`, `contract-testing`, `react-typescript`,
`unit-integration-testing`.

## Execution steps

1. **Justify** the endpoint: is synchronous HTTP right, or should this be an event
   (`microservice-design`)? Stop if an event fits better.
2. **Spec first**: edit `contracts/openapi/<service>.v1.yaml` — path, parameters, request/
   response schemas, problem responses, `security`, `Idempotency-Key`/`ETag` where applicable.
3. **Classify** the change: additive vs breaking. Breaking → `/v2` path; keep `/v1` until
   consumers migrate.
4. **Lint** the spec: `npx @redocly/cli lint contracts/openapi/<service>.v1.yaml`.
5. **Implement** in the service (owning engineer): controller/handler → use case →
   ports; problem-details mapping; authZ including object ownership.
6. **Tests** in the service: slice/handler tests for status codes and problems; security
   negative tests; provider Pact verification state handlers.
7. **Consumers** (frontend engineer): regenerate client (`npm run api:generate`), update
   Pact consumer tests.
8. **Review**: `code-review`; `security-audit` for public, payment or PII endpoints.

## Validation steps

- Spec lint passes; implemented routes match the spec (integration test or contract test).
- Service build/tests pass from its folder.
- Consumer typecheck and Pact tests pass; provider verification passes.
- Negative security tests: 401 without token, 403/404 for other users' resources.

## Expected output

Spec diff, compatibility classification, implementation files, tests and their results,
regenerated client files, review verdict.

## Failure handling

| Situation | Action |
|---|---|
| Breaking change requested on `/v1` | Propose `/v2` and a migration plan via `commerce-architect`. |
| Linter unavailable | Run YAML parse at least; report lint as not run. |
| Pact broker not running | Run consumer tests locally (pact files produced); report verification as pending. |
| Endpoint needs another service's data | Use an event-fed projection or a documented call; never another database. |
