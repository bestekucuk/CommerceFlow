# 0011. Independent build, release and deployment per service

- Status: Proposed
- Date: 2026-11-12
- Deciders: project owner, devops-engineer, commerce-architect
- Affected areas: `.github/workflows`, `infrastructure/kubernetes`, every `services/*` and `apps/*` Dockerfile

## Context

ADR-0004 keeps all code in one repository but requires that services remain
independently deployable. Without explicit release rules, a monorepo drifts into "deploy
everything on every merge", which couples releases and hides compatibility problems.

## Decision

- Each service and app has its own CI workflow, triggered only by changes to its folder,
  the contracts it produces or consumes, or its own workflow file.
- Each produces its own container image tagged with the git commit SHA; images are
  immutable and promoted between environments, never rebuilt.
- Each is deployed as its own Helm release, at its own time, by its own pipeline.
- A deployment is allowed only if it is compatible with the versions currently running in
  the target environment: Pact `can-i-deploy` for HTTP, Schema Registry compatibility for
  events, expand/contract for migrations.
- There is no "release train" that deploys all services together.

Details: `docs/architecture/build-and-release-strategy.md`.

## Alternatives considered

- **Release train (all services together)** — simpler coordination and testing of one
  combination; loses independent delivery and makes every release large.
- **Semantic version tags per service** — human-readable; added later if external
  consumers need them. SHA tags are sufficient for internal deployment.

## Consequences

- Compatibility checks become release gates and must be reliable.
- Environments run mixed versions by design; tests must cover old/new combinations for
  contract changes.
- Per-service pipelines duplicate some YAML; reusable workflows limit this
  (`github-actions-cicd`).
