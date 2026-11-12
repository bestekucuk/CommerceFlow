# Agent Catalog

The CommerceFlow Claude Code engineering team. Definitions live in `.claude/agents/`.
Agents implement or review; they do not create business functionality on their own
initiative — every task comes from the user or a plan.

## Team

| Agent | Role | Model | Tools | Writes |
|---|---|---|---|---|
| `commerce-architect` | Principal Software Architect | opus | Read, Grep, Glob, Write, Edit | `docs/architecture/`, `docs/adr/`, `docs/agent-catalog.md`, `backlog/` |
| `kotlin-backend-engineer` | Senior Kotlin Engineer | sonnet | Read, Grep, Glob, Write, Edit, Bash | one of `services/{product,order,payment,customer,pricing}-service` + its own `contracts/openapi/` spec |
| `golang-backend-engineer` | Senior Go Engineer | sonnet | Read, Grep, Glob, Write, Edit, Bash | one of `services/{inventory,shipping,notification}-service` + its own `contracts/openapi/` spec |
| `frontend-engineer` | Senior React Engineer | sonnet | Read, Grep, Glob, Write, Edit, Bash | one of `apps/{admin,storefront}-web` |
| `database-engineer` | Database Architect | sonnet | Read, Grep, Glob, Write, Edit, Bash | one service's migrations (and persistence queries when tasked), `infrastructure/postgres/` |
| `event-driven-engineer` | Distributed Systems Engineer | opus | Read, Grep, Glob, Write, Edit, Bash | `contracts/events/`, `contracts/schemas/`, `docs/event-catalog/`, `infrastructure/{kafka,debezium}/` |
| `test-engineer` | QA Automation Architect | sonnet | Read, Grep, Glob, Write, Edit, Bash | `tests/`; a service's/app's test folders when tasked |
| `devops-engineer` | Platform Engineer | sonnet | Read, Grep, Glob, Write, Edit, Bash | `docker-compose.yml`, `infrastructure/{docker,redis,monitoring,kubernetes}/`, `.github/workflows/`, `scripts/`, Dockerfiles when tasked |
| `security-reviewer` | Application Security Engineer | opus | Read, Grep, Glob, Bash | nothing (findings only) |
| `code-reviewer` | Senior Code Reviewer | opus | Read, Grep, Glob, Bash | nothing (findings only) |

Model choice: `opus` for design, cross-cutting judgement and independent review;
`sonnet` for scoped implementation.

## Ownership map

| Path | Owner | Notes |
|---|---|---|
| `services/{product,order,payment,customer,pricing}-service` | kotlin-backend-engineer | migrations co-owned with database-engineer |
| `services/{inventory,shipping,notification}-service` | golang-backend-engineer | migrations co-owned with database-engineer |
| `apps/*` | frontend-engineer | |
| `contracts/events/`, `contracts/schemas/` | event-driven-engineer | |
| `contracts/openapi/<service>.*` | that service's language engineer | breaking change → commerce-architect plan |
| `infrastructure/kafka/`, `infrastructure/debezium/` | event-driven-engineer | |
| `infrastructure/postgres/` | database-engineer | wired into Compose/Helm by devops-engineer |
| `docker-compose.yml`, other `infrastructure/*`, `.github/`, `scripts/` | devops-engineer | |
| `tests/` | test-engineer | |
| `docs/architecture/`, `docs/adr/`, `backlog/`, this file | commerce-architect | |
| `docs/runbooks/` | devops-engineer (platform), event-driven-engineer (messaging) | |
| `.claude/` | the user | no agent edits Claude configuration |

## Collaboration rules

1. **Service ownership.** An agent changes only the folders it owns, and implementation
   agents work in one service or app per task.
2. **Cross-service changes go through the architect.** Any task touching more than one
   service, app or a shared contract starts with a `commerce-architect` plan
   (planning step of `/implement-feature`). The plan names one owning agent per step; the main session
   dispatches them in order. Subagents cannot start other subagents.
3. **Independent review.** After implementation, `code-reviewer` reviews the diff without
   the implementer's reasoning. `security-reviewer` additionally reviews changes to
   authentication, authorization, secrets, public APIs, dependencies or infrastructure
   exposure. Reviewers never fix; findings go back to the owning agent.
4. **Least privilege.** The architect has no shell; the reviewers have no write tools.
   Shell access exists only where a build, test, scan or validation must run.
5. **Truthful reporting.** Every agent reports the commands it actually ran and their real
   results.
6. **No publishing.** No agent pushes, adds remotes, deploys, applies Terraform or pushes
   images. The workspace hook blocks `git push` and remote changes.

## Typical flow

```
user request
  └─ commerce-architect      plan (if cross-service or a decision)
       ├─ event-driven-engineer   contract change
       ├─ database-engineer       migration
       ├─ kotlin/golang/frontend  implementation (one folder each)
       ├─ test-engineer           cross-service tests
       └─ devops-engineer         images, compose, pipelines
  └─ code-reviewer           independent review
  └─ security-reviewer       when security-relevant
```

## Monorepo knowledge every agent carries

Root architecture (`CLAUDE.md`, `docs/architecture/`), service ownership (above),
independent builds per folder (no root build), independent Docker images, shared event
contracts in `contracts/`, centralized tests in `tests/`, and workspace-level Claude Code
configuration in `.claude/` (skills, commands, hook).
