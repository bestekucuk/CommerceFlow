---
name: implement-feature
description: Workflow to implement a CommerceFlow feature end to end - analyse the request, identify affected services and contracts, get an architect plan for cross-service work, delegate each step to the owning agent, run the component tests, get an independent code review and report. Use when the user asks to build or change a feature or backlog item.
argument-hint: "<backlog-id> <feature description>"
---

# implement-feature

## Purpose

Turn a feature request into reviewed, tested changes while respecting service ownership:
one owning agent per folder, contracts first, independent review last.

## Invocation

```text
/implement-feature CF-010 "Order saga happy path: reserve inventory, authorize payment, confirm"
```

Also selected automatically when the user asks to implement a feature or backlog item.

## Input parameters

| Parameter | Required | Source |
|---|---|---|
| Backlog ID | yes (ask if missing) | `$ARGUMENTS` first token or `backlog/BACKLOG.md` |
| Feature description | yes | rest of `$ARGUMENTS` |
| Constraints (deadline, scope limits) | no | user |

## Required context

- Root `CLAUDE.md`; `docs/agent-catalog.md` (ownership map); `docs/architecture/overview.md`.
- `docs/architecture/service-catalog.md`, `docs/event-catalog/README.md`.
- The `CLAUDE.md` of every component the feature touches.
- Relevant ADRs in `docs/adr/`.

## Relevant agents

`commerce-architect` (plan), `event-driven-engineer` (contracts), `database-engineer`
(migrations), `kotlin-backend-engineer` / `golang-backend-engineer` / `frontend-engineer`
(implementation), `test-engineer` (cross-service tests), `devops-engineer` (compose/CI),
`code-reviewer` (always), `security-reviewer` (when security-relevant).

## Relevant skills

`microservice-design`, `domain-driven-design`, `create-domain-event`, `create-api`,
`write-tests`, `code-review`, `security-audit`, `prepare-pull-request`.

## Execution steps

1. **Clarify** the outcome and acceptance criteria in two or three bullet points. Ask the
   user only if the request is ambiguous about behaviour, not about implementation details.
2. **Map impact:** list services, apps, contracts and infrastructure the feature touches,
   with the reason for each. Use the event catalog to find consumers of changed events.
3. **Plan:**
   - One component → write the plan yourself (files, layers, tests).
   - More than one component or any contract → delegate to `commerce-architect` for an
     ordered, independently deployable step plan (contracts → consumers → producers).
   Present the plan and wait for the user's approval before editing files.
4. **Execute steps in order**, one Agent call per step, each to the owning agent named in
   the plan, with: backlog ID, the single folder it may change, the contract files it must
   follow, and the acceptance criteria. Independent steps may run in parallel.
5. **After each implementation step** run that component's tests (the agent does; verify its
   reported command and result).
6. **Cross-service behaviour** → `test-engineer` adds/updates tests in `tests/integration`
   (and `tests/e2e` for user journeys) — see `write-tests`.
7. **Review:** run `code-review` on the full diff; add `security-audit` if auth, PII,
   payments, public endpoints, secrets or infrastructure exposure changed.
8. **Fix loop:** send blocking/major findings back to the owning agent; re-review.
9. **Report** (and offer `prepare-pull-request`).

## Validation steps

- Every changed path belongs to a component named in the plan
  (`powershell -File scripts/affected-components.ps1`).
- Each touched component's own build/tests pass from its folder.
- Contract changes classified and catalog updated (Stop hook A1 must be quiet).
- `code-review` verdict is `approve` or `approve with comments`.
- No step left the system non-deployable (architect's "deploy-safe because" column holds).

## Expected output

- Plan (approved) with steps, owners and status.
- Changed files grouped by component.
- Commands run with real results.
- Review verdict and resolved findings.
- Open risks and follow-up backlog items.
- Nothing committed or pushed unless the user asks for a commit.

## Failure handling

| Situation | Action |
|---|---|
| Owning agent reports a needed change outside its folder | Stop that step; return to the architect plan; add a step for the right owner. |
| Tests fail and the cause is in another component | Do not patch across boundaries; report the defect with owner. |
| Review returns `changes required` twice | Escalate to the user with the remaining findings. |
| Build tooling missing (scaffold-only component) | Report that tests could not run; do not claim the feature works. |
| User rejects the plan | Revise the plan; no files are edited before approval. |
