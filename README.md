# CommerceFlow

Event-driven e-commerce platform built as a **modular monorepo of independently
deployable microservices**: one repository, eight backend services, two frontends.

## Status

Scaffold only. The repository contains structure, documentation and Claude Code
configuration. No application code, build files or infrastructure manifests exist yet,
and `docker-compose.yml` is a placeholder — nothing builds or runs.

## Layout

```
commerceflow/
├── .claude/              Claude Code agents, skills, commands, hooks, settings
├── services/             product, order, inventory, payment, customer, pricing, shipping, notification
├── apps/                 admin-web, storefront-web
├── contracts/            events (Avro), openapi, schemas
├── infrastructure/       docker, postgres, kafka, debezium, redis, monitoring, kubernetes
├── tests/                integration, contract, e2e, performance, resilience
├── docs/                 architecture, adr, event-catalog, runbooks
├── backlog/              BACKLOG.md
├── scripts/
├── docker-compose.yml
└── CLAUDE.md
```

## Stack

Kotlin + Spring Boot (product, order, payment, customer, pricing) · Go (inventory,
shipping, notification) · React + TypeScript (admin-web, storefront-web) · PostgreSQL ·
Redis · Kafka · Debezium · Schema Registry · Docker · Kubernetes · Helm · Terraform ·
OpenTelemetry, Prometheus, Grafana, Loki, Tempo · JUnit 5, Go testing, Testcontainers,
Pact, Playwright, k6, Toxiproxy.

## Start here

1. `docs/adr/0004-modular-monorepo.md` — why a monorepo, and what stays independent.
2. `docs/architecture/overview.md` — contexts, events, saga.
3. `backlog/BACKLOG.md` — what to build next.

## Remote

Remote: `origin` → https://github.com/bestekucuk/CommerceFlow (public). Claude adds no
remotes and never pushes; pushes are made by the owner. CI: `.github/workflows/`
(see `docs/architecture/build-and-release-strategy.md`).
