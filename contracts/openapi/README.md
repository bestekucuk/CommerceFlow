# OpenAPI contracts

Status: **in use**: `product-service.v1.yaml`. Linted in CI (`.github/workflows/contracts.yml`,
Redocly). One OpenAPI 3.1 document per service HTTP API:
`<service>.v<major>.yaml` (e.g. `order-service.v1.yaml`).

- Written API-first; the service implements it, frontends generate clients from it.
- Breaking changes need a new major version and path prefix (`/v2/...`).
- Pact tests (`tests/contract/`) verify providers against consumer expectations.
