---
name: service-scaffold
description: Conventions for turning a documentation-only CommerceFlow service folder into a buildable Kotlin/Spring Boot or Go service inside the monorepo. Use when creating the first code in services/<name>-service.
---

# Service scaffold

Read the target service's `CLAUDE.md` first; it names the language, package and bounded
context. Do not change other service folders.

## Independence in the monorepo

- The service gets its **own** build in its folder: Gradle wrapper + `settings.gradle.kts`
  (Kotlin) or `go.mod` + `Makefile` (Go). Do not add it to a root multi-project build.
- Code generated from `contracts/` is produced by the service's own build, into its own
  build output.
- Its own `Dockerfile` in its folder; build context is the service folder plus
  `contracts/` only.

## Kotlin / Spring Boot

- Gradle Kotlin DSL with the Gradle wrapper committed; JVM toolchain pinned.
- Package root `com.commerceflow.<context>`.
- Layout:
  ```
  src/main/kotlin/com/commerceflow/<context>/
    domain/          entities, value objects, domain events, repository ports (no Spring)
    application/     use cases, inbound and outbound ports
    adapters/in/     web (REST controllers), messaging (Kafka listeners + inbox)
    adapters/out/    persistence (JPA or jOOQ), outbox writer, HTTP clients
    config/          Spring wiring only
  src/main/resources/db/migration/   Flyway migrations (includes outbox and inbox tables)
  src/test/kotlin/...                JUnit 5; Testcontainers for adapters
  ```
- Actuator health, Micrometer Prometheus endpoint, OpenTelemetry Java agent or starter.

## Go

- Own Go module in the service folder, module path
  `github.com/commerceflow/commerceflow/services/<name>-service` (placeholder until a
  remote exists). No `go.work` that ties services together.
- Layout:
  ```
  cmd/<name>-service/main.go
  internal/domain/        entities, value objects, events, repository interfaces
  internal/application/   use cases
  internal/adapters/      http, kafka (consumer + inbox), postgres (repos + outbox), redis
  internal/platform/      config, logging, telemetry
  migrations/             SQL migrations (includes outbox and inbox tables)
  ```
- `log/slog` structured logs, OpenTelemetry Go SDK, `/healthz` and `/metrics` endpoints.

## Both

- Multi-stage Dockerfile, non-root user.
- Build, test and lint runnable from the service folder.
- Add the service to root `docker-compose.yml` and its database to
  `infrastructure/postgres/`.
- Verify the build and tests pass before reporting the scaffold is done.
