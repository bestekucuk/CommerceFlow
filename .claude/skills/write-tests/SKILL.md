---
name: write-tests
description: Workflow to add CommerceFlow tests at the right level of the testing pyramid - unit tests for domain and use cases, Testcontainers integration tests for adapters, Pact contract tests, cross-service integration, Playwright E2E, k6 performance and Toxiproxy resilience - placed in the correct monorepo folder and actually run. Use when code lacks tests or a change needs coverage.
argument-hint: "<component or path> [behaviour to cover]"
---

# write-tests

## Purpose

Cover a behaviour with the cheapest test that can catch its failure, in the folder that
owns it, and prove the tests run.

## Invocation

```text
/write-tests services/inventory-service "reservation is atomic under concurrency"
/write-tests apps/storefront-web checkout
```

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Component or path | yes | `services/<x>`, `apps/<x>`, or a file |
| Behaviour / risk | no | if missing, derive from the uncommitted diff or recent changes |

## Required context

The component's `CLAUDE.md`; the code under test; `docs/event-catalog/README.md` for
messaging; `tests/<area>/README.md` for cross-service layers.

## Relevant agents

`test-engineer` (owner of `tests/` and test strategy), the component's language engineer
(service-local tests), `frontend-engineer` (app tests), `code-reviewer`.

## Relevant skills

`unit-integration-testing`, `testcontainers`, `contract-testing`, `playwright-e2e`,
`performance-testing`, `resilience-testing`.

## Execution steps

1. **Inventory** existing tests for the component; list behaviours and which are uncovered.
2. **Choose the layer** per behaviour:

   | Behaviour | Layer | Location |
   |---|---|---|
   | Invariant, calculation, state transition | unit | service `src/test/...` / `*_test.go` |
   | Use case orchestration | unit with fakes | service |
   | SQL, outbox, inbox, Kafka adapter | Testcontainers integration | service (tagged) |
   | HTTP contract with an app | Pact consumer + provider | app `tests/pact`, service verification |
   | Flow across services | integration on Compose | `tests/integration` |
   | User journey | Playwright | `apps/<app>/tests/e2e` or `tests/e2e` |
   | Latency/throughput SLO | k6 | `tests/performance` |
   | Behaviour under faults | Toxiproxy | service (single dependency) or `tests/resilience` |

3. **Write** the tests (owning agent per location); for every message handler include a
   duplicate-delivery test; for every saga step a dependency-unavailable test.
4. **Run** them (commands below) and fix test defects; production defects are reported, not
   patched by the test author.
5. **Report** coverage of the listed behaviours.

## Validation steps

- Kotlin service: `(cd services/<x> && ./gradlew build)`.
- Go service: `(cd services/<x> && go test -race ./... && go test -race -tags=integration ./...)`.
- App: `(cd apps/<x> && npm run typecheck && npm test)`.
- Cross-service: run the relevant command from `tests/<area>/README.md` against Compose.
- No `sleep` in tests; async assertions use bounded polling.
- The test-reminder Stop hook is quiet (tests ran after the last edit).

## Expected output

Table of behaviours → test files → layer → result (pass/fail with counts), plus any
production defects found with the owning agent.

## Failure handling

| Situation | Action |
|---|---|
| Docker unavailable | Write the tests; report integration tests as not run. |
| Component has no build files yet | Report that tests cannot run; suggest `create-service`/scaffold first. |
| Test reveals a production bug | Keep the failing test, report the defect to the owner; do not weaken the assertion. |
| Flaky result | Rerun once to classify; fix the cause (shared state, timing) before reporting green. |
