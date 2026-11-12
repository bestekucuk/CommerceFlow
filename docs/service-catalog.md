# Service catalog — build and run

Status: **implemented as buildable scaffolds** (2026-11-12). Every service and app below
builds, tests and produces its own Docker image from its own folder. None contains
business logic, APIs beyond health endpoints, or Kafka integration yet.

Architecture view (contexts, responsibilities, databases): `docs/architecture/service-catalog.md`
and `docs/architecture/service-definitions.md`.

## Components

| Component | Path | Stack | Build tool | Port | Liveness | Readiness | Migrations | Image |
|---|---|---|---|---|---|---|---|---|
| product-service | `services/product-service` | Kotlin 2.0, Spring Boot 3.3 | Gradle 8.10.2 wrapper | 8081 | `/actuator/health/liveness` | `/actuator/health/readiness` (incl. DB) | Flyway `V1` outbox | `commerceflow/product-service` |
| order-service | `services/order-service` | Kotlin, Spring Boot | Gradle wrapper | 8082 | same | same | Flyway `V1` outbox, inbox | `commerceflow/order-service` |
| payment-service | `services/payment-service` | Kotlin, Spring Boot | Gradle wrapper | 8084 | same | same | Flyway `V1` outbox, inbox | `commerceflow/payment-service` |
| customer-service | `services/customer-service` | Kotlin, Spring Boot | Gradle wrapper | 8085 | same | same | Flyway `V1` outbox | `commerceflow/customer-service` |
| pricing-service | `services/pricing-service` | Kotlin, Spring Boot | Gradle wrapper | 8086 | same | same | Flyway `V1` outbox, inbox | `commerceflow/pricing-service` |
| inventory-service | `services/inventory-service` | Go 1.23, pgx v5, slog | Go module + Makefile | 8083 | `/healthz` | `/readyz` (DB ping) | golang-migrate `000001` outbox, inbox | `commerceflow/inventory-service` |
| shipping-service | `services/shipping-service` | Go, pgx, slog | Go module + Makefile | 8087 | `/healthz` | `/readyz` | `000001` outbox, inbox | `commerceflow/shipping-service` |
| notification-service | `services/notification-service` | Go, pgx, slog | Go module + Makefile | 8088 | `/healthz` | `/readyz` | `000001` inbox | `commerceflow/notification-service` |
| admin-web | `apps/admin-web` | React 18, TypeScript strict, Vite 5 | npm | 5173 (dev), 8080 (container) | `/healthz` | `/readyz` | — | `commerceflow/admin-web` |
| storefront-web | `apps/storefront-web` | React 18, TypeScript strict, Vite 5 | npm | 5174 (dev), 8080 (container) | `/healthz` | `/readyz` | — | `commerceflow/storefront-web` |

## Commands

From the repository root (Windows PowerShell 5.1+ or `pwsh`):

| Goal | Command |
|---|---|
| Build one component | `powershell -File scripts/build-service.ps1 <name>` |
| Build one component + image | `powershell -File scripts/build-service.ps1 <name> -Image` |
| Test one component | `powershell -File scripts/test-service.ps1 <name>` |
| Test one component incl. integration/E2E | `powershell -File scripts/test-service.ps1 <name> -Integration` |
| Build all | `powershell -File scripts/build-all.ps1 [-Image]` |
| Test all | `powershell -File scripts/test-all.ps1 [-Integration]` |
| Which components does my change affect? | `powershell -File scripts/affected-components.ps1 [base]` |

What each script runs, per type:

| Type | build | test | -Integration |
|---|---|---|---|
| Kotlin | `gradlew build` (compile, unit + ArchUnit tests, bootJar) | `gradlew test` | `gradlew integrationTest` (Testcontainers, Docker) |
| Go | `go vet`, gofmt check, `go test`, `go build` | `go test ./...` | `go test -tags=integration ./tests/...` (Docker) |
| Web | `npm ci`, `tsc --noEmit`, `vite build` | typecheck + `vitest run` | `playwright test` (needs `npx playwright install chromium`) |

Go runs locally when Go is installed, otherwise inside `golang:1.23` (module and build
caches in Docker volumes `commerceflow-go-mod`, `commerceflow-go-build`).

Images are built with the component folder as context plus
`--build-context contracts=contracts` (reserved for contract code generation, CF-003).

## Independence

- Each component has its own build file, lockfile/wrapper, tests and Dockerfile.
- There is no root build; `build-all`/`test-all` only loop over components and call each
  one's own tooling, continuing after failures.
- Building or testing one component never builds another.
- No shared runtime library exists; only `contracts/` is shared.

## Verification log (2026-11-12, this machine)

Environment: Windows 10, JDK 18.0.1, Node 24.22 / npm 8.5, Docker Engine 29.9 (Docker
Desktop), no local Go (Go ran in `golang:1.23`).

| Component | Build | Unit tests | Integration tests | Image |
|---|---|---|---|---|
| product, order, payment, customer, pricing | ok | 3/3 ArchUnit each | 2/2 each (Testcontainers PostgreSQL) | see below |
| inventory, shipping, notification | ok | config + router tests ok | readiness + migration test ok | see below |
| admin-web, storefront-web | ok | 1/1 each | Playwright **not run** (browsers not installed) | see below |

Images: recorded in the completion report of the scaffolding change.

## Known constraints

- Testcontainers 1.19 (managed by Spring Boot 3.3) defaults to a Docker API version that
  Docker Engine 29 rejects; each Kotlin `integrationTest` task sets
  `systemProperty("api.version", "1.44")`.
- Kotlin bytecode targets Java 17 so the build runs on the installed JDK 18; images use
  Temurin 17. Moving to Java 21 is a later, per-service decision.
- `npm` 8.5 with Node 24 works but is old; CI should use the Node 20 LTS image used in the
  Dockerfiles.
