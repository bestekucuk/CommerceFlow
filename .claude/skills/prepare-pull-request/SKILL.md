---
name: prepare-pull-request
description: Workflow to prepare a CommerceFlow pull request description - summary per component, linked backlog items and ADRs, contract and migration changes, deployment order for independently deployed services, tests actually run with results, review and audit outcomes, risks, rollback notes and screenshots for UI changes. Produces text only; never pushes, opens or merges a PR on its own. Use when the user wants to open a PR or summarize a branch.
argument-hint: "[base-ref]"
disable-model-invocation: true
---

# prepare-pull-request

## Purpose

Give reviewers everything they need to judge a change in one description, with only
verified claims.

## Invocation

```text
/prepare-pull-request          # branch vs main (or uncommitted vs HEAD on main)
/prepare-pull-request main
```

Manual only. The output is a Markdown description; opening the PR is the user's action.

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Base ref | no | default `main`; if on `main`, uses uncommitted changes vs `HEAD` |

## Required context

`git log <base>..HEAD`, `git diff <base> --stat`, backlog items referenced in commits,
ADRs touched, results of `code-review`, `security-audit`, `write-tests`, `run-e2e` from this
session (if any).

## Relevant agents

`code-reviewer` (if no review exists yet), `test-engineer` (test summary), the owning
engineers (component summaries on request).

## Relevant skills

`code-review`, `security-audit`, `run-e2e`, `database-migration-review`,
`schema-evolution`.

## Execution steps

1. **Collect** commits and diff; map to components with
   `powershell -File scripts/affected-components.ps1 <base>`.
2. **Ensure evidence exists**: if no review in this session, run `code-review`; if
   migrations changed, run `database-migration-review`; if contracts changed, list
   compatibility results; if UI changed, offer `run-e2e` for screenshots.
3. **Deployment order**: contracts → consumers → producers; migrations before code that
   needs them; note feature flags.
4. **Draft** the description with the template below. Every test line must come from a
   command actually run in this session, with its real result; otherwise write "not run".
5. **Show** it to the user. If the user asks, save it to a file they name. Creating the PR
   (`gh pr create --draft`) only on explicit request and only when a remote exists; merging
   is never done by Claude (guard hook denies `gh pr merge`).

## Validation steps

- Every changed component appears in the summary.
- Every claim in "Tests" maps to a command and result from this session.
- Risks include migrations, contract changes and cross-service ordering when present.
- No secrets, internal credentials or personal data in the description.

## Expected output

```markdown
## Summary
<one paragraph: what and why> (CF-010)

## Changes by component
- `services/order-service` — saga state machine, outbox commands
- `contracts/events/inventory` — ReserveInventory.v1 (new)

## Contracts & migrations
- New: ReserveInventory.v1 (BACKWARD compatible, catalog updated)
- order-service V5__saga_instance.sql — additive, reviewed (database-migration-review)

## Deployment order
1. contracts registered 2. inventory-service 3. order-service

## Tests
- `services/order-service: ./gradlew build` — ✅ 148 passed
- `tests/e2e checkout.spec.ts` — not run (stack not available)

## Review
code-review: approve with comments (2 minor) · security-audit: not required

## Risks & rollback
<risks>; rollback: redeploy previous image; migration is additive

## Screenshots
<paths from run-e2e, if UI changed>
```

## Failure handling

| Situation | Action |
|---|---|
| No commits and no changes | Report nothing to describe. |
| Tests never ran | Say so explicitly in the Tests section; recommend `write-tests`/`run-e2e`. |
| No remote configured | Provide the text only; note the user must add a remote to open a PR. |
| Review found blocking issues | Put them at the top under "Blocking issues"; recommend not opening the PR yet. |
