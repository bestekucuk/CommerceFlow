# 0001. Polyrepo with a platform repository

- Status: Superseded by [0004](0004-modular-monorepo.md) (2026-11-12)
- Date: 2026-11-12
- Affected repositories: all

## Context

CommerceFlow consists of eight backend services and two frontends owned by separate
bounded contexts. Each should be built, versioned and deployed independently.

## Decision

Each service and frontend lives in its own Git repository. `commerceflow-platform` holds
cross-cutting artifacts: architecture docs, ADRs, event contracts, infrastructure and the
backlog. A workspace folder (not a repository) groups the repositories locally and holds
the shared Claude Code configuration.

## Alternatives considered

- Monorepo — atomic cross-service changes and simpler tooling, but couples build and
  release, and makes it easy to bypass context boundaries.

## Consequences

- Cross-repo changes become ordered sequences of compatible changes (see workspace
  `CLAUDE.md`).
- Contracts need a distribution mechanism from the platform repo to services
  (CF-003, decision pending).
- Workspace tooling (`/workspace-status`) is needed to see overall state.
