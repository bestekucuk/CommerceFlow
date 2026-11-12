---
name: architecture-review
description: Workflow to inspect CommerceFlow architecture - service boundaries, data ownership, cross-service imports and database access, contract and event-catalog consistency, independent builds and pipelines, Clean Architecture layering and ADR compliance - for a diff, a component or the whole repository, producing findings and recommended ADRs. Use for design reviews or before large changes.
argument-hint: "[diff|component|all]"
---

# architecture-review

## Purpose

Detect drift from the architecture defined in ADR-0002/0003/0004 before it becomes
coupling: one owner per datum, contracts as the only shared artifact, independent builds.

## Invocation

```text
/architecture-review            # uncommitted diff
/architecture-review services/order-service
/architecture-review all
```

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Scope | no | `diff` (default), a component path, or `all` |

## Required context

Root `CLAUDE.md`, ADRs 0002–0004, `docs/architecture/overview.md`,
`docs/architecture/service-catalog.md`, `docs/event-catalog/README.md`,
`docs/agent-catalog.md`, component `CLAUDE.md` files.

## Relevant agents

`commerce-architect` (performs the review and drafts ADRs), `event-driven-engineer`
(contract consistency), `code-reviewer` (layering details).

## Relevant skills

`microservice-design`, `clean-architecture`, `domain-driven-design`, `schema-evolution`,
`architecture-decision-records`.

## Execution steps

1. **Scope** the files (`git diff --name-only HEAD`, a folder, or `git ls-files`).
2. **Boundary checks** (deterministic):
   - Kotlin imports of other contexts: `grep -rn "import com.commerceflow\." services/<svc>`
     excluding the service's own package.
   - Go imports of sibling modules, `replace ../` in `go.mod`, any `go.work`.
   - Connection strings to other services' `_db`; shared tables; `dblink`/`postgres_fdw`.
   - Root build files that aggregate services (`settings.gradle.kts` at root, root `go.mod`,
     root workspaces in `package.json`).
3. **Contract consistency**: every event in `contracts/events` has a catalog row and vice
   versa; producers/consumers in the catalog exist; topics follow naming.
4. **Independence**: each service/app has its own build file, Dockerfile (if scaffolded),
   CI workflow with path filters including consumed contracts.
5. **Layering** (sample or all files in scope): domain free of framework imports; ArchUnit /
   Go arch tests present.
6. **Data ownership**: each table written by exactly one service; projections built from
   events.
7. **ADR compliance**: decisions in code contradict an accepted ADR? Missing ADR for a new
   decision?
8. **Report** and propose ADRs / backlog items.

## Validation steps

- Each finding cites file:line or catalog row.
- Checks 2–4 executed for the whole scope (state counts: files scanned, services checked).
- The Stop hook `check-architecture-docs` reports no A1–A7 issue for the reviewed diff.

## Expected output

```markdown
## Architecture review — scope: <scope>
Verdict: compliant | drift found | violations found
| Severity | Rule | Location | Finding | Recommendation |
|---|---|---|---|---|
| violation | database per service | services/pricing-service/.../application.yml:12 | connects to product_db | consume ProductCreated into own projection |
Proposed ADRs: ...
Checked: 8 services, 2 apps, 23 schemas, 412 files
```

## Failure handling

| Situation | Action |
|---|---|
| Scope too large to read fully | Run all deterministic checks; sample layering; state the sample. |
| Rule conflict between ADRs | Report it; propose a superseding ADR. |
| Finding needs code change | Hand over to the owning agent via `implement-feature`; the review itself changes nothing. |
