# tests/integration

Cross-service tests against the local Compose stack. Their own Go module (`go.mod` here);
they depend on no service code — only on HTTP APIs, Kafka, Schema Registry and Tempo.

Tests that cover a single service live inside that service's folder.

| Test | Covers | Tag |
|---|---|---|
| `product_cdc_e2e_test.go` | HTTP → product-service (product + outbox, one tx) → WAL → Debezium Outbox Event Router → `cf.product.events.v1` (key, headers, Avro envelope) → inventory-service consumer (inbox) → stock item; one correlation id and one trace in Tempo | `e2e` |

## Running

```bash
powershell -File infrastructure/scripts/up.ps1
powershell -File infrastructure/scripts/register-schemas.ps1
powershell -File infrastructure/scripts/migrate.ps1 -Service product
powershell -File infrastructure/scripts/migrate.ps1 -Service inventory
docker compose --profile apps up -d --build product-service inventory-service
powershell -File infrastructure/scripts/register-connectors.ps1 -Service product
powershell -File tests/integration/run-e2e.ps1
```

`run-e2e.ps1` runs the tests in a `golang:1.23` container attached to the
`commerceflow_default` network, so they use container names (`product-service:8081`,
`kafka:29092`, …). Override with `E2E_*` environment variables when running elsewhere.
