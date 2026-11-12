# 0004. Modular monorepo with independently deployable services

- Status: Accepted (2026-11-12, decided by the project owner)
- Date: 2026-11-12
- Supersedes: [0001](0001-polyrepo-strategy.md)
- Affected areas: whole repository

## Context

ADR-0001 proposed one Git repository per service plus a platform repository. In
practice most early work crosses services (contracts, saga steps, local stack), and a
polyrepo turns each such change into an ordered series of commits across repositories
with no single review.

## Decision

All of CommerceFlow lives in **one Git repository**: services, frontends, contracts,
infrastructure, tests, docs and backlog.

**Monorepo does not mean monolith.** Every service stays:

- **Independently buildable** — its own build (Gradle wrapper, `go.mod` or
  `package.json`) inside its folder. No root build that compiles everything together, no
  dependency from one service's build on another service's code.
- **Independently testable** — its own unit and integration tests runnable from its
  folder; cross-service tests live in `tests/`.
- **Independently deployable and scalable** — its own container image, Helm release and
  CI pipeline triggered by changes to its folder or to the contracts it uses.
- **Owner of its domain and its PostgreSQL database.** No service reads or writes
  another service's database.

Allowed sharing: the schemas in `contracts/`. Each service generates its own code from
them. There are no shared domain or utility libraries between services.

## Layout

```
services/<name>-service/   one bounded context each
apps/<name>-web/           frontends
contracts/                 events (Avro), openapi, schemas
infrastructure/            docker, postgres, kafka, debezium, redis, monitoring, kubernetes
tests/                     integration, contract, e2e, performance, resilience
docs/                      architecture, adr, event-catalog, runbooks
backlog/  scripts/  docker-compose.yml
```

## Alternatives considered

- Polyrepo (ADR-0001) — strongest isolation, but slow, unreviewable cross-service
  changes and duplicated tooling.
- Monorepo with a single multi-module build — simplest tooling, but couples builds and
  invites shared code that erodes service boundaries.

## Consequences

- Cross-service changes can land in one commit, but deployment is still per service, so
  every change must stay compatible with the previously deployed versions of other
  services (contract-first, consumers before producers).
- Boundaries are enforced by convention and tests, not by repository walls: CF-022 adds
  architecture tests that fail on cross-service imports.
- CI needs path filters per service (CF-020) and a script that detects affected
  services (CF-021).
- The 11 polyrepo repositories were replaced by this repository; their single bootstrap
  commits were archived outside the repository, not merged.
