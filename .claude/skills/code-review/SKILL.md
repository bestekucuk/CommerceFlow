---
name: code-review
description: Workflow to review changed CommerceFlow code independently - collect the diff, map it to components, check boundaries and architecture, correctness, security basics, maintainability and test coverage, run each touched component's tests, and report severity-ranked findings with a verdict, using the code-reviewer agent. Use after any implementation and before a commit or pull request.
argument-hint: "[base-ref | path]"
---

# code-review

## Purpose

An independent, evidence-based review of a change. The reviewer judges code against the
repository rules, not the implementer's explanation, and never edits files.

## Invocation

```text
/code-review                 # uncommitted changes vs HEAD
/code-review main            # branch diff vs main
/code-review services/order-service
```

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Base ref or path | no | default `HEAD` (uncommitted changes) |

## Required context

Root `CLAUDE.md`; touched components' `CLAUDE.md`; ADR-0002, ADR-0004; contracts touched;
the detailed checklist and commands in `reference/review-guide.md` (this skill folder).

## Relevant agents

`code-reviewer` (performs the review — run it as a subagent so it starts without the
implementer's context), `security-reviewer` (escalation).

## Relevant skills

`clean-architecture`, `transactional-outbox`, `idempotent-consumer`,
`transaction-management`, `database-migrations`, `unit-integration-testing`,
`security-audit`.

## Execution steps

1. **Collect** the diff: `git diff <base> --stat` and changed files; map to components with
   `powershell -File scripts/affected-components.ps1 <base>`.
2. **Delegate** to the `code-reviewer` agent with: base ref, file list, component list, and
   "follow `.claude/skills/code-review/reference/review-guide.md`". Do not pass the
   implementer's reasoning.
3. The reviewer, in order: scope & boundaries → architecture (layers, outbox/inbox,
   transactions, migrations, contracts) → correctness → tests → security basics →
   performance → maintainability.
4. The reviewer runs each touched component's build/tests from its folder.
5. **Escalate** to `security-audit` when auth, secrets, PII, payments or exposure changed.
6. **Return** the report to the user unchanged in substance; propose next steps (owners for
   each blocking/major finding).

## Validation steps

- Every changed file was read (reviewer lists them).
- Boundary checks were executed (commands and their output summary are in the report).
- Builds/tests were run or the reason is stated.
- Verdict matches findings: any blocking → `changes required`.

## Expected output

```markdown
**Verdict:** approve | approve with comments | changes required
| Severity | Location | Finding | Why it matters | Direction | Owner |
|---|---|---|---|---|---|
**Ran:** <commands and real results>
**Not verified:** <items>
```

## Failure handling

| Situation | Action |
|---|---|
| Empty diff | Report "nothing to review". |
| Diff spans several services without a plan | Blocking finding: request a `commerce-architect` plan (`implement-feature`). |
| Tests cannot run | Verdict at most `approve with comments`, list what was not verified. |
| Reviewer and implementer disagree | Present both positions to the user; the user decides. |
