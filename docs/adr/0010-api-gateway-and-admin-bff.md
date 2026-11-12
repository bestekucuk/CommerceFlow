# 0010. API gateway for client traffic and a backend-for-frontend for admin-web

- Status: Proposed
- Date: 2026-11-12
- Deciders: project owner, commerce-architect, security-reviewer
- Affected areas: `apps/admin-web`, `apps/storefront-web`, `infrastructure/kubernetes`, service APIs

## Context

Two browser applications call several services. Without an edge component each service
must be exposed publicly, CORS and rate limits are configured eight times, and the admin
UI needs pages that combine data from several contexts (e.g. order with payment and
shipment status). Admin users handle sensitive operations; keeping their tokens out of
the browser reduces the impact of XSS.

## Decision

- **API gateway** (planned): the single public entry point for both apps. It terminates
  TLS, routes `/<service>/v1/...` to services, applies rate limits, request size limits and
  CORS, and propagates `traceparent`. It forwards the bearer token; **services still
  validate tokens and authorize** (no trust in the gateway alone). It contains no business
  logic. Product choice (e.g. an ingress-based gateway or a dedicated gateway) is open.
- **Admin BFF** (planned): a small backend owned by the admin-web team that
  - implements the OIDC token-handler pattern (session cookie to the browser, tokens kept
    server-side),
  - composes read views by calling **service APIs only**,
  - forwards commands to the owning service API unchanged in meaning.
  It has **no database of business data** and never reads service databases. Its location
  in the repository is decided when it is built (CF-024).
- **Storefront** calls services through the gateway with an access token obtained via
  Authorization Code + PKCE and held in memory; no BFF initially.

## Alternatives considered

- **No gateway, services exposed directly** — fewer components; duplicated edge concerns
  and a larger attack surface.
- **One BFF for both apps** — less code; couples two UIs with different users, release
  cadence and security needs.
- **GraphQL federation layer** — flexible composition; a large new technology and a place
  where business logic tends to accumulate.

## Consequences

- Two new deployables (gateway configuration, admin BFF) with their own pipelines.
- The BFF must not become an "admin backend" that bypasses service ownership; reviews check
  that it only calls `contracts/openapi` APIs.
- Gateway routes and service OpenAPI specs must stay aligned.
