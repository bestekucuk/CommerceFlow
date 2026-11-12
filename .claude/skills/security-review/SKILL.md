---
name: security-review
description: Perform a CommerceFlow security review of a diff, component or design - scope, STRIDE threat model, OWASP Top 10 and API Security Top 10 checks mapped to this stack, authN/authZ verification, secrets and dependency scanning (gitleaks, govulncheck, npm audit, OWASP dependency-check, Trivy) and a severity-ranked findings report. Used by the security-reviewer agent; reports findings without modifying code.
---

# Security review

## Purpose

Find exploitable weaknesses before they ship, with evidence and a clear owner for every
finding. The reviewer reports; owners fix (`secure-backend-development`).

## When to use

- Changes to authentication, authorization, public APIs, payment or PII handling.
- New dependencies, Dockerfiles, Helm values, network exposure or secrets handling.
- Design reviews for new services or integrations.

## Prerequisites

- The diff (`git diff <base>...HEAD` or uncommitted `git diff HEAD`) or named components.
- Agent: `security-reviewer` (read-only tools + Bash for scanners).

## Concepts and architecture

**STRIDE per trust boundary**

| Threat | CommerceFlow examples |
|---|---|
| Spoofing | Forged JWT, missing `aud` check, trusting internal headers |
| Tampering | Price manipulated in checkout request; Kafka message forged by another client |
| Repudiation | Admin price change without audit trail |
| Information disclosure | Order of another customer (IDOR), PII in logs/events, stack traces |
| Denial of service | Unbounded page sizes, no rate limit on login/checkout, regex DoS |
| Elevation of privilege | Customer token calling admin endpoints, missing method security |

**OWASP API Top 10 mapping:** BOLA → object ownership checks; broken authentication →
JWT validation; BOPLA → DTO allow-lists (no mass assignment); unrestricted resource
consumption → limits/rate limiting; BFLA → role checks per operation; SSRF → outbound URL
allow-lists (carrier/payment adapters); misconfiguration → actuator exposure, CORS;
improper inventory → OpenAPI vs implemented endpoints; unsafe consumption of APIs →
validate payment/carrier responses.

## Step-by-step workflow

1. Scope: list changed files and map to components (`powershell -File scripts/affected-components.ps1`).
2. Identify entry points (endpoints, consumers, admin actions) and assets (money, PII,
   credentials).
3. Threat-model with STRIDE for each new/changed trust boundary.
4. Code review against the checklist below.
5. Run scanners for touched components.
6. Write the report; classify severity; assign owning agent.

## Practical code examples

Checklist (copy into the review):

```markdown
- [ ] Every new endpoint: authenticated; scope/role; object-level ownership check
- [ ] JWT: issuer, audience, algorithm pinned; no custom parsing
- [ ] Request DTOs allow-list fields; price/total never accepted from client
- [ ] Inputs bounded (lengths, page size, array sizes); validation errors don't leak internals
- [ ] SQL parameterized; no string-built queries; no dynamic ORDER BY without allow-list
- [ ] Outbound URLs from config/allow-list only (SSRF)
- [ ] No secrets/PII in code, config, logs, events, test fixtures
- [ ] Actuator exposes only health/info/prometheus; CORS explicit origins
- [ ] Dockerfile non-root, pinned base; Helm securityContext restrictive
- [ ] New dependencies justified, maintained, no known critical CVEs
```

Scanner commands (run from the component folder unless noted):

```bash
# secrets in the diff / history (repo root)
gitleaks git --no-banner --log-opts="origin/main..HEAD"    # gitleaks v8.19+; older: gitleaks detect --source .
# Go
go run golang.org/x/vuln/cmd/govulncheck@latest ./...
# Kotlin/Gradle (requires the org.owasp.dependencycheck plugin in that service build)
./gradlew dependencyCheckAnalyze
# web apps
npm audit --omit=dev --audit-level=high
# container image (after docker build)
trivy image --severity HIGH,CRITICAL commerceflow/order-service:dev
# IaC / Helm values
trivy config infrastructure/kubernetes
```

If a scanner is not installed, say so in the report; do not install global tools without
the user's approval.

Finding format:

```markdown
| Severity | Component | Location | Issue | Evidence | Fix guidance | Owner |
|---|---|---|---|---|---|---|
| High | order-service | adapters/in/web/OrderController.kt:42 | BOLA: GET /v1/orders/{id} returns any order | Request with customer B token returns order of A (no ownership check in GetOrder) | Check `order.customerId == caller` in GetOrder; return 404 | kotlin-backend-engineer |
```

Severity guide: **Critical** — remote exploitation without auth or mass data exposure;
**High** — auth bypass, IDOR, secret exposure; **Medium** — needs preconditions, DoS,
missing hardening with real impact; **Low** — defense-in-depth gaps.

## Recommended project structure

Review outputs are reported in the conversation/PR, not committed. Threat models for new
services may be added to `docs/architecture/` by the `commerce-architect`.

## Best practices

- Evidence for every finding (line, request, scanner output excerpt).
- Prefer fewer, verified findings over long speculative lists.
- Check what the diff *removed* (deleted checks, relaxed configs).
- State explicitly what was not reviewed or could not be scanned.

## Anti-patterns

- Fixing code during the review.
- Printing secret values found; reference location only.
- Generic OWASP lists without mapping to the actual code.
- Running exploits against non-local environments.

## Failure scenarios

| Situation | Handling |
|---|---|
| Scanner unavailable | Report "not run" with reason; recommend adding it to CI. |
| Secret found in history | Critical finding; recommend rotation and history cleanup; do not print it. |
| Design-only review | Threat model + required controls list; no scanners. |

## Testing strategy

Each High/Critical finding should come with a suggested regression test (e.g. "customer B
token → 404 on order A") for the owner to add.

## Definition of Done

- Scope and entry points listed; STRIDE done for changed boundaries.
- Checklist completed; scanners run or reasons stated.
- Findings ranked with evidence, fix guidance and owning agent.
- Explicit "not covered" section.
