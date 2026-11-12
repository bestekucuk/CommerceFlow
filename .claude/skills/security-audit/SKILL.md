---
name: security-audit
description: Workflow to audit CommerceFlow security for a diff, a component or the whole repository - threat model, authentication and JWT validation, function- and object-level authorization, input handling and injection, secrets in code and history, dependency and image vulnerabilities, API exposure and infrastructure configuration - delegated to the security-reviewer agent and reported with severity and owners. Use for security-relevant changes and before releases.
argument-hint: "[diff|component|all]"
---

# security-audit

## Purpose

A structured, evidence-based security assessment that ends in a prioritized list of
findings with owners. The audit reports; it never fixes.

## Invocation

```text
/security-audit                          # uncommitted diff
/security-audit services/payment-service
/security-audit all                      # pre-release
```

## Input parameters

| Parameter | Required | Notes |
|---|---|---|
| Scope | no | `diff` (default), component path, or `all` |

## Required context

Root `CLAUDE.md`; components' `CLAUDE.md`; `contracts/openapi/` (exposed endpoints);
`docker-compose.yml`, `infrastructure/`; `.claude/settings.json` deny rules;
`docs/hook-catalog.md` (secret detection already in place).

## Relevant agents

`security-reviewer` (performs the audit), owning engineers (fixes, later),
`devops-engineer` (infrastructure findings).

## Relevant skills

`security-review` (method, checklist, scanners), `secure-backend-development` (expected
controls), `rest-api-design`.

## Execution steps

1. **Scope** files and entry points (endpoints, consumers, admin actions, public apps).
2. **Delegate** to `security-reviewer` with the scope and "follow the `security-review`
   skill".
3. Reviewer performs: STRIDE per changed trust boundary → authN (issuer, audience,
   algorithm) → authZ (scopes, object ownership, admin paths) → input/injection/SSRF/mass
   assignment → data exposure (PII in logs/events/errors) → secrets → dependencies and
   images → configuration (actuator, CORS, Compose/Helm security context, network policies).
4. Scanners (if installed; no global installs without approval): `gitleaks`, `govulncheck`,
   `npm audit`, Gradle dependency-check, `trivy image`/`trivy config`.
5. **Consolidate** findings, deduplicate, assign owners per the agent catalog.
6. **Report**; for High/Critical include a suggested regression test.

## Validation steps

- Every in-scope entry point has an authN and authZ verdict.
- Each finding has evidence (file:line or reproducible request) and an owner.
- Scanner list shows run / not run with reasons.
- Secret values are never printed.

## Expected output

```markdown
## Security audit — scope: <scope>, <git sha>
Summary: 0 critical, 1 high, 2 medium, 1 low
| Severity | Component | Location | Issue | Evidence | Fix guidance | Owner |
|---|---|---|---|---|---|---|
Threat model: <boundaries and top threats>
Scanners: gitleaks ✅ clean · govulncheck ✅ 0 · npm audit ⚠️ 1 moderate · trivy not run (not installed)
Not covered: <items>
```

## Failure handling

| Situation | Action |
|---|---|
| Secret found | Critical; recommend rotation and history cleanup; reference location only. |
| Scanner missing | Report not run; suggest adding it to the component's CI. |
| Design-only scope (no code yet) | Threat model + required controls checklist. |
| Finding disputed | Present evidence and the rule; the user decides. |
