---
name: code-review
description: Review a CommerceFlow change independently - collect the diff, check monorepo boundaries (no cross-service imports, shared libraries or foreign database access), Clean Architecture layering, outbox/inbox and transaction rules, correctness, tests, performance and maintainability, run the component's build and tests, and report severity-ranked findings with a verdict. Used by the code-reviewer agent; does not modify code.
---

# Code review

## Purpose

An independent second look that protects architecture and correctness. The reviewer
judges the code against repository rules, not the implementer's explanation.

## When to use

- After any implementation by an agent or a person, before commit/merge.
- On request for a specific component or commit range.

## Prerequisites

- Diff to review: default `git diff HEAD` (uncommitted) or `git diff <base>...HEAD`.
- Agent: `code-reviewer` (Read, Grep, Glob, Bash for git and running tests).
- Rules: root `CLAUDE.md`, the touched components' `CLAUDE.md`, ADR-0002/0004.

## Concepts and architecture

Review order — stop and report blocking issues early:

1. **Scope & boundaries** (blocking if violated)
2. **Architecture** (layering, ports, outbox/inbox, transactions)
3. **Correctness** (logic, errors, concurrency, edge cases)
4. **Tests** (presence, layer, quality — and they pass)
5. **Security basics** (authZ, validation, secrets) — escalate deeper issues to
   `security-review`
6. **Performance** (N+1, unbounded work, missing indexes)
7. **Maintainability** (naming, duplication, clarity)

Severity: **blocking** (must fix: boundary/architecture violation, bug, data loss, security
hole, failing tests), **major** (should fix before merge), **minor**, **nit**.

## Step-by-step workflow

1. Collect changed files and map them to components.
2. Run the boundary checks below.
3. Read every changed file fully, plus the code it calls.
4. Run each touched component's build/tests from its folder.
5. Write findings with file:line, why it matters and a direction (not a full patch).
6. Give the verdict consistent with the findings.

## Practical code examples

Scope and boundary commands:

```bash
git diff --name-only HEAD | awk -F/ '{print ($1=="services"||$1=="apps") ? $1"/"$2 : $1}' | sort | uniq -c
# Kotlin: imports of other contexts
git diff HEAD -- 'services/*.kt' | grep -E '^\+.*import com\.commerceflow\.' 
# Go: replace directives or imports of sibling services
git diff HEAD -- 'services/*/go.mod' | grep -E '^\+.*replace'
git diff HEAD -- 'services/*.go' | grep -E '^\+.*"github.com/commerceflow/commerceflow/services/'
# other services' databases in config
git diff HEAD | grep -E '^\+.*(jdbc:postgresql|postgres://)[^ ]*/(product|order|inventory|payment|customer|pricing|shipping|notification)_db'
```

Interpret: a Kotlin import of `com.commerceflow.<other context>` or a Go import of another
service module is **blocking**; a datasource pointing at another service's `_db` is
**blocking**.

Architecture checks while reading:

```text
domain/      no Spring/JPA/Kafka/Jackson/pgx/net/http imports
application/ no adapters imports; @Transactional boundary here
publishing   events only via outbox inside the same transaction (no KafkaTemplate/ProduceSync for domain events)
consuming    inbox insert + effects in one transaction; offset commit after commit
migrations   expand/contract safe; lock_timeout; concurrent indexes isolated
contracts    schema change classified; catalog updated; consumers first for additive changes
```

Run tests for touched components:

```bash
(cd services/order-service && ./gradlew build)
(cd services/inventory-service && make lint test)
(cd apps/storefront-web && npm run typecheck && npm test)
```

Report template:

```markdown
**Verdict:** changes required

| Severity | Location | Finding | Why it matters | Direction |
|---|---|---|---|---|
| blocking | services/order-service/.../ConfirmOrder.kt:31 | Publishes OrderConfirmed with KafkaTemplate after commit | Dual write: event lost on crash between commit and send | Record via OrderEvents (outbox) inside the transaction |
| major | services/inventory-service/internal/adapters/kafka/consumer.go:88 | Commits offsets of records after a failed one | Skips the failed message permanently | Stop at first failure; return error (see kafka-event-driven) |
| minor | ... | ... | ... | ... |

**Ran:** `./gradlew build` (order-service): passed, 142 tests. `make test` (inventory-service): 1 failure (TestReserve_Concurrent).
**Not verified:** Debezium end-to-end (stack not running).
```

## Recommended project structure

Reviews are reported in the conversation or PR; nothing is committed by the reviewer.

## Best practices

- Review the change, not the author; be specific and actionable.
- Prefer one clear finding over several vague ones.
- Point to the skill or ADR that defines the rule being violated.
- Separate "must fix" from preferences (nits).
- Approve only what you could build and test, or say what you could not run.

## Anti-patterns

- Rubber-stamping because the implementer says tests pass.
- Rewriting the code in the review instead of describing the problem.
- Style debates that a formatter/linter should settle.
- Reviewing only the diff hunks without reading the surrounding code.

## Failure scenarios

| Situation | Handling |
|---|---|
| Build cannot run (no Docker / tool missing) | Verdict at most "approve with comments", list what was not verified. |
| Diff touches several services without a plan | Blocking: ask for a `commerce-architect` plan (`/cross-service-change`). |
| Huge diff | Review boundaries and architecture first; request splitting if necessary. |

## Testing strategy

The reviewer runs the component's own tests and checks that new behaviour is covered at
the right layer (`unit-integration-testing`); missing tests for new logic are at least
"major".

## Definition of Done

- All changed files read; boundary and architecture checks performed explicitly.
- Builds/tests of touched components run (or reason stated).
- Findings ranked with location, rationale and direction.
- Verdict consistent with findings (any blocking → changes required).
