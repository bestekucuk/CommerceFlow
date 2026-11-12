# Workflow Catalog

Workflow skills orchestrate agents and knowledge skills for a recurring engineering task.
They live in `.claude/skills/<name>/SKILL.md` like every other skill — Claude Code's
current convention merges custom commands into skills, so CommerceFlow has **no**
`.claude/commands/` folder. Knowledge skills are listed in `docs/skill-catalog.md`.

Every workflow defines: Purpose, Invocation, Input parameters, Required context, Relevant
agents, Relevant skills, Execution steps, Validation steps, Expected output, Failure
handling.

## Invocation

- Type `/<workflow> <arguments>`; arguments reach the skill as `$ARGUMENTS`
  (`argument-hint` in the frontmatter shows the expected shape).
- Workflows without `disable-model-invocation` are also chosen automatically when the
  request matches their description.
- `create-service`, `run-e2e` and `prepare-pull-request` set
  `disable-model-invocation: true`: they start containers, create many files or prepare
  publication, so only the user starts them.
- Workflows run in the main session, which delegates steps to agents (subagents cannot
  start other subagents).

## Workflows

| Workflow | Invocation | Purpose | Lead agent(s) | Key skills | Output | Auto-invocable |
|---|---|---|---|---|---|---|
| `implement-feature` | `/implement-feature CF-010 "<feature>"` | Analyse a feature, identify affected services, plan, delegate per owner, test, review | commerce-architect → owning engineers → code-reviewer | microservice-design, create-domain-event, create-api, write-tests, code-review | Approved plan, changes by component, test results, review verdict | yes |
| `create-service` | `/create-service <name>-service <kotlin\|go> "<context>"` | New independently deployable service under `services/` | commerce-architect, language engineer, database/event-driven/devops engineers | microservice-design, kotlin-springboot / golang-development, debezium-cdc, docker-kubernetes, github-actions-cicd | Service folder, infra entries, ADR, build/image results | no |
| `create-api` | `/create-api <service> "<METHOD /v1/path>" "<purpose>"` | Versioned REST API, OpenAPI-first | language engineer, frontend-engineer | rest-api-design, secure-backend-development, contract-testing | Spec diff, implementation, provider/consumer tests | yes |
| `create-domain-event` | `/create-domain-event <Event> <producer> <consumers...>` | Versioned event contract + catalog + producer/consumer steps | event-driven-engineer, commerce-architect | schema-evolution, transactional-outbox, idempotent-consumer | Schema, catalog row, topic, rollout order | yes |
| `write-tests` | `/write-tests <component> ["behaviour"]` | Tests at the right pyramid level, in the right folder, actually run | test-engineer, owning engineer | unit-integration-testing, testcontainers, contract-testing, playwright-e2e, performance-testing, resilience-testing | Behaviour → test → result table | yes |
| `run-e2e` | `/run-e2e [app/spec] [--full]` | Run relevant Playwright specs against the healthy Compose stack, report | test-engineer | playwright-e2e, distributed-tracing | E2E report with traces/screenshots | no |
| `architecture-review` | `/architecture-review [diff\|component\|all]` | Boundaries, ownership, contracts, independence, layering, ADR compliance | commerce-architect | microservice-design, clean-architecture, architecture-decision-records | Findings + proposed ADRs | yes |
| `code-review` | `/code-review [base\|path]` | Independent review of changed code | code-reviewer | clean-architecture, transactional-outbox, idempotent-consumer (+ `reference/review-guide.md`) | Verdict, ranked findings, commands run | yes |
| `debug-event-flow` | `/debug-event-flow <eventId\|aggregateId\|topic> [service]` | Read-only trace through DB → outbox → slot → Debezium → Kafka → consumer → inbox/DLT | event-driven-engineer | transactional-outbox, debezium-cdc, kafka-event-driven, idempotent-consumer, retry-and-dead-letter-queue | Hop table + cause + owner | yes |
| `database-migration-review` | `/database-migration-review [file\|service]` | Locking, data loss, compatibility, rollback risk; verified on a disposable DB | database-engineer | database-migrations, postgresql-design, transaction-management | Statement-level risk table, verification result | yes |
| `security-audit` | `/security-audit [diff\|component\|all]` | AuthN/Z, secrets, vulnerabilities, exposure | security-reviewer | security-review, secure-backend-development | Severity-ranked findings, threat model, scanner results | yes |
| `prepare-pull-request` | `/prepare-pull-request [base]` | PR description with summary, tests, risks, deployment order, screenshots | main session (+ code-reviewer if needed) | code-review, run-e2e, database-migration-review | Markdown description (text only) | no |

## How workflows chain

```text
/implement-feature
   ├─ plan (commerce-architect)       ── /architecture-review for large designs
   ├─ /create-domain-event, /create-api   (contract steps)
   ├─ owning engineers implement       ── /database-migration-review if migrations changed
   ├─ /write-tests                     ── /run-e2e for user journeys
   ├─ /code-review                     ── /security-audit when security-relevant
   └─ /prepare-pull-request            (user opens the PR; Claude never pushes or merges)
/debug-event-flow                      (incidents; read-only)
```

## Shared helper

`scripts/affected-components.ps1 [base] [-Json]` maps changed paths to components,
including producers and consumers of changed contracts (from the event catalog) and apps
that call a changed API. Used by implement-feature, code-review, run-e2e and
prepare-pull-request.

## Guarantees enforced by hooks while workflows run

See `docs/hook-catalog.md`: no push/merge/deploy/destructive migration (denied), local
irreversible commands need the user's confirmation, secrets cannot be written or
committed, edited files are format-checked, documentation drift and untested changes are
flagged before Claude finishes.
