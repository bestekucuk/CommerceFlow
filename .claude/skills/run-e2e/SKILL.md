---
name: run-e2e
description: Workflow to run the relevant CommerceFlow end-to-end tests - pick Playwright specs affected by the change, check the local Docker Compose stack is healthy, run them headless, collect traces and screenshots, correlate failures with service traces and logs, and write a test report. Never deploys or resets data. Use when the user asks to run E2E or verify a journey.
argument-hint: "[app or spec filter] [--full]"
disable-model-invocation: true
---

# run-e2e

## Purpose

Produce a trustworthy E2E report for the change at hand: what ran, what passed, what
failed and why.

## Invocation

```text
/run-e2e                      # specs relevant to uncommitted changes
/run-e2e storefront checkout  # filter by app and spec name
/run-e2e --full               # whole tests/e2e suite
```

Manual only: it starts containers and generates traffic.

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| App / spec filter | no | e.g. `storefront`, `checkout`, `admin price` |
| `--full` | no | run every spec in `tests/e2e` and both apps |

## Required context

`tests/e2e/playwright.config.ts`, `apps/*/tests/e2e/`, root `docker-compose.yml`,
`docs/architecture/service-catalog.md` (ports), the uncommitted diff.

## Relevant agents

`test-engineer` (runs and analyses), `frontend-engineer` (UI failures), language engineers
(service failures).

## Relevant skills

`playwright-e2e`, `distributed-tracing`, `observability`.

## Execution steps

1. **Select specs**: map changed components (`powershell -File scripts/affected-components.ps1`)
   to specs (app folder → its specs; service → journeys that call it; `--full` → all).
2. **Check the stack**: `docker compose ps`; if services are not running, ask the user
   before `docker compose up -d` (never `down -v`, never data resets).
3. **Health gate**: wait for readiness endpoints of required services (bounded, e.g. 120 s);
   fail fast with which service is unhealthy.
4. **Run**: `npx playwright test <filter> --reporter=list,html` from `tests/e2e` (or the app
   folder for app-local specs). Test credentials come from environment variables only.
5. **Collect** on failure: `test-results/**/trace.zip`, screenshots, the trace id shown in
   the UI or response; query Tempo/Loki for that trace when the monitoring stack runs.
6. **Report**.

## Validation steps

- The report lists every executed spec with status and duration.
- Each failure has evidence (assertion message, trace/screenshot path, service trace id).
- No command in the run modified or deleted data volumes (guard hook would ask).

## Expected output

```markdown
## E2E report — <date>, <git sha>
Stack: compose services healthy: 12/12
| Spec | Project | Result | Duration |
|---|---|---|---|
| checkout.spec.ts › customer buys an in-stock product | storefront | ✅ passed | 14.2 s |
| admin-price.spec.ts › admin edits price | admin | ❌ failed | 8.9 s |
Failures:
- admin-price: expected price 12,99 € got 11,99 € (trace: test-results/.../trace.zip, service trace 4bf92f…)
Screenshots: test-results/admin-price-.../test-failed-1.png
Not run: none
```

## Failure handling

| Situation | Action |
|---|---|
| Stack not running and user declines start | Report "not run" with reason. |
| Service unhealthy | Report the service and its last log lines; do not run specs. |
| Flaky failure (passes on retry) | Report as flaky with both results; open a follow-up. |
| Playwright not installed | `npx playwright install --with-deps` only with user approval (download). |
