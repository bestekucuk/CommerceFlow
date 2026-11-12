# CommerceFlow engineering framework audit

- Date: 2026-11-12
- Scope: whole repository at the working tree on top of `a728da9` (uncommitted: Prompt 07
  infrastructure, Prompt 09 product → inventory CDC slice, audit fixes)
- Method: deterministic checks (scripts, validators, builds, tests, a live stack) plus
  manual reading. Every PASS below cites evidence produced during this audit.
- Independence caveat: the auditor is the same assistant that built most of the framework.
  To compensate, verdicts rely on executed checks, and the latest code change was given to
  the `code-reviewer` agent for an independent review (result in section 8).

Legend: ✅ pass · ❌ fail · ⚠️ pass with risk/limitation.

## 1. Summary

| Area | Result |
|---|---|
| Claude Code configuration | ✅ valid; 3 documentation inconsistencies fixed |
| Skills | ✅ 43 skills (31 knowledge + 12 workflow) valid, unique; 2 contradictions fixed |
| Agents | ✅ 10 agents valid; least privilege holds; no ownership conflicts |
| Monorepo boundaries | ✅ one repository, no nested `.git`, no cross-service imports or database access |
| Event architecture | ✅ outbox → Debezium → Kafka → idempotent consumer verified end to end for ProductCreated; ⚠️ 24 of 25 catalogued messages have no schema yet; saga not implemented |
| CI/CD | ❌ no pipelines exist (no remote); local scripts only |
| Backlog | ✅ 83 tasks; statuses updated with this audit's evidence (13 Done, 5 In progress) |
| Readiness | Local development: **ready**. Shared environments / production: **not ready** (section 9) |

## 2. Claude Code configuration

| # | Check | Result | Evidence |
|---|---|---|---|
| C1 | Root `CLAUDE.md` exists and its path references resolve | ✅ | audit script C1/C2: every `docs/`, `scripts/`, `infrastructure/`, `contracts/`, `backlog/`, `tests/` path in it exists |
| C2 | Every service/app has `CLAUDE.md` with a Status section | ✅ | audit script M4/C3 (10/10) |
| C3 | Service statuses match reality | ❌→✅ fixed | product-service and inventory-service said "No business logic yet" although both now contain the CDC slice; rewritten to list what is implemented and what is not |
| C4 | No duplicate command mechanism | ✅ | `.claude/commands` absent; workflows are skills |
| C5 | `settings.json` valid; hooks reference existing scripts; matchers use known tools | ✅ | `validate-all.sh`: 8 hook entries ok |
| C6 | Hooks behave as documented | ✅ | `Test-Hooks.ps1`: **85/85**. Observed live in this session: the Stop hooks `remind-tests` and `check-architecture-docs` (rule A1) blocked a turn and were satisfied by running tests and updating the event catalogue; `detect-secrets` ran on real commits |
| C7 | Permission rules | ⚠️ | deny list blocks push, remote changes, `gh pr merge`, `terraform apply/destroy`, `helm install/upgrade`, `kubectl apply/delete`, `Read(.env)`. `Read(.env)` does not stop `cat .env` through Bash (see security risks) |

## 3. Skills

| # | Check | Result | Evidence |
|---|---|---|---|
| S1 | Valid frontmatter, name = directory, unique names | ✅ | `validate-all.sh`: 31 knowledge + 12 workflow, ALL CHECKS PASSED; audit script S1 |
| S2 | Required sections (12 knowledge / 10 workflow), code examples, no placeholders | ✅ | same validator (section order, ≥2 code blocks, placeholder scan) |
| S3 | Workflows reference existing agents, skills, scripts | ✅ | same validator |
| S4 | No contradictory instructions | ❌→✅ fixed | (a) `kotlin-springboot` and `docker-kubernetes` prescribed Java 21 images/toolchain while the repository builds Java 17 bytecode on Temurin 17 — aligned to the repository; (b) `debezium-cdc` and its reference connector prescribed `ByteArrayConverter`, which fails at runtime with PostgreSQL `bytea` (observed) — changed to `io.debezium.converters.BinaryDataConverter` |
| S5 | Examples match local ports | ❌→✅ fixed | `kotlin-springboot` example and 8 service configs/READMEs used `localhost:5432`; the stack now publishes PostgreSQL on 15432 |
| S6 | Testing requirements present | ✅ | every knowledge skill has "Testing strategy"; every workflow has "Validation steps" (validator) |

Residual risk: skill code examples outside the implemented slice are templates that have
not been compiled (stated in `docs/skill-catalog.md`).

## 4. Agents

| # | Check | Result | Evidence |
|---|---|---|---|
| A1 | Valid definitions (name, description, tools, model) and required sections | ✅ | `validate-agents.sh`: ALL CHECKS PASSED |
| A2 | Least privilege | ✅ | reviewers have no Write/Edit; `commerce-architect` has no shell (audit script A2) |
| A3 | No conflicting ownership | ✅ | `docs/agent-catalog.md` ownership map assigns each path to one owner; shared write areas are none (migrations co-owned explicitly with `database-engineer`) |
| A4 | Delegation boundaries | ✅ | implementation agents limited to one folder; cross-service work requires an architect plan; subagents cannot start subagents (documented) |
| A5 | Independent review used in practice | ✅ | the CDC slice was reviewed by `code-reviewer` without the implementer's reasoning (section 8) |

## 5. Monorepo architecture

| # | Check | Result | Evidence |
|---|---|---|---|
| M1 | Exactly one Git repository; no nested `.git` | ✅ | audit script M1/M2 |
| M2 | No root build | ✅ | no root `settings.gradle.kts`, `go.mod`, `go.work`, `package.json` |
| M3 | Each of the 8 services and 2 apps has `CLAUDE.md`, README, Dockerfile, own build, migrations (services) | ✅ | audit script M4 (10/10) |
| M4 | Independent build and test commands | ✅ | `scripts/build-service.ps1`, `test-service.ps1`; run in this audit for product-service (23 unit tests) and inventory-service (4 packages ok) |
| M5 | No cross-service code imports | ✅ | audit script M5 (Kotlin imports, Go module imports, `replace` directives) + ArchUnit rules + Stop hook A7 |
| M6 | No cross-service database access | ✅ | static: no service references another `<svc>_db` (M6). Runtime: `health.ps1` — no service role can connect to another service's database; `CONNECT` revoked from `PUBLIC` |
| M7 | Database ownership documented | ✅ | `docs/architecture/database-ownership.md`, `docs/architecture/service-catalog.md` |

## 6. Event architecture

| # | Check | Result | Evidence |
|---|---|---|---|
| E1 | Transactional outbox | ✅ | product-service writes product and outbox row in one transaction; `OutboxAtomicityIT` 3/3 (commit, failure-after-outbox rollback, duplicate-SKU rollback); no Kafka producer dependency |
| E2 | Debezium CDC with Outbox Event Router | ✅ | `verify-cdc.ps1` passed; E2E passed; failure mode found and fixed (converter) |
| E3 | Kafka topics, keys, retention, DLTs declared | ✅ | `topics.csv` (9 + 14 DLT + check topic) created and verified by `health.ps1` (24/24); auto topic creation off |
| E4 | Event schemas | ⚠️ | `EventMetadata.v1`, `ProductCreated.v1` exist, parse (Avro compiler, hamba) and are registered; the other 24 catalogued events/commands are planned (CF-002) |
| E5 | Schema compatibility | ⚠️ | subject set to BACKWARD; `register-schemas.ps1 -CheckOnly` works locally; not enforced in CI (no CI) |
| E6 | Idempotent consumer / inbox | ✅ | inventory-service: inbox in the handler transaction; `TestConsumer_DuplicateDeliveryHasOneEffect` passed; E2E restart showed no re-processing |
| E7 | Retry and DLQ | ✅ | `TestConsumer_PoisonMessageIsDeadLetteredAndPartitionContinues`, `TestConsumer_RetriesTransientFailuresWithoutSkipping` passed |
| E8 | Saga design | ⚠️ | designed (ADR-0009, `communication-patterns.md`, state machine) — not implemented (CF-010/011) |
| E9 | Tracing across the async hop | ✅ | E2E: one trace contains product-service and inventory-service spans in Tempo; same `trace_id`/`correlation_id` in both services' logs |

## 7. CI/CD

| # | Check | Result | Evidence |
|---|---|---|---|
| CI1 | Service-specific pipelines | ❌ | no `.github/workflows`; CF-020 blocked because the repository has no remote |
| CI2 | Change detection | ⚠️ | `scripts/affected-components.ps1` maps changes (incl. contract consumers) — not wired into CI |
| CI3 | Independent Docker builds | ✅ | 10/10 images built separately earlier; product and inventory images rebuilt and run in this audit |
| CI4 | Contract compatibility checks | ⚠️ | local only (`register-schemas.ps1 -CheckOnly`); Pact not set up (CF-017) |
| CI5 | Automated test execution | ❌ | tests run only locally through scripts |
| CI6 | Deployment separation | ❌ | no deployment exists (Helm/Kubernetes planned, CF-019/081) |

## 8. Independent code review of the CDC slice

The `code-reviewer` agent reviewed the Prompt 09 diff (product-service, inventory-service,
contracts, E2E test). Verdict: **approve with comments**. Every finding was handled as below
and the affected tests were rerun afterwards.

| # | Severity | Finding | Resolution | Evidence |
|---|---|---|---|---|
| 1 | major | inventory: event/product ids not validated as UUIDs; a malformed id fails the `uuid` column and is retried forever | `Validate` checks UUIDs; SQLSTATE classes 22/23 map to `ErrInvalidEvent` → DLT | unit table tests; IT `TestConsumer_PermanentDataErrorsAreDeadLettered` |
| 2 | major | inventory: retries while `BlockRebalanceOnPoll` is held can block a group rebalance indefinitely | `AllowRebalance()` before every retry sleep | consumer ITs (restart, transient retries) pass |
| 3 | major | product: `use.latest.version=true` writes with whatever version is newest; a future v2 would corrupt records | writer schema pinned to the generated class (`use.latest.version=false`, `avro.remove.java.properties=true`, no auto-register) | live registry lookup: class schema without Java properties = id 1; product IT 11/11; E2E PASS with schema id 1 |
| 4 | minor | inventory: shutdown waited for the whole poll batch | ctx checked before each record; uncommitted records are redelivered | restart IT |
| 5 | minor | inventory: SKU already owned by another product was silently accepted | `CreateStockItems` returns `ErrInvalidEvent` → DLT | IT |
| 6 | minor | readiness DOWN while retrying not documented | documented as a deliberate choice in `services/inventory-service/README.md` | — |
| 7 | minor | OTel Java agent downloaded without integrity check | `ADD --checksum=sha256:fa039f86…7d5b` in the product Dockerfile | image rebuilt, container healthy, E2E PASS |
| 8 | minor | no outbox/inbox cleanup | backlog item CF-084 | `backlog/TASKS.md` |
| 9 | minor | APIs have no authentication | already planned (CF-065, CF-068); OpenAPI declares `security: []` explicitly | — |

Note on 7: the checksum was taken from the agent already downloaded into the previous
image (trust on first use); it was not compared against an upstream-published digest.

## 9. Readiness assessment

| Use | Assessment |
|---|---|
| Local development with Claude Code | **Ready.** Config, agents, skills, workflows and hooks are valid and exercised; the stack is verified healthy; the first vertical slice works end to end with tests at every layer. |
| Building further features (phases 4–7) | **Ready to proceed**, with CF-002 (remaining schemas) and CF-003 (Go codegen decision) as next prerequisites. |
| Shared/staging environment | **Not ready**: no CI, no remote, no authentication (CF-065/068), no Helm/Kubernetes, no secrets management. |
| Production | **Not ready**: above plus SLOs (CF-025), RPO/RTO (CF-027), retention (CF-026), production Debezium (CF-083). |

## 10. Architecture risks

| Risk | Impact | Mitigation / backlog |
|---|---|---|
| Single local PostgreSQL instance; no Debezium heartbeat | idle-database slots retain WAL produced by others (capped at 2 GB locally) | documented; production design with heartbeats (CF-083) |
| Debezium converter mismatch class of errors | connector task fails and stops CDC | fixed; add a CDC smoke test to CI (CF-037 in CI) |
| Schema evolution enforced only by convention | an incompatible change could be deployed | CI compatibility job (CF-040) |
| Go consumer decodes with a hand-written struct | struct can drift from the contract | contract test uses the real `.avsc`; decide Go codegen (CF-003) |
| Transient failures retry indefinitely on one partition | a long outage stalls the partition (by design, no skipping) | readiness turns DOWN, metric `commerceflow_message_retries_total`; alert rule pending (CF-079) |
| Avro serialization needs Schema Registry at write time | product creation fails if the registry is down (transaction rolls back — safe but unavailable) | documented in `outbox-design.md`; consider caching/HA registry |

## 11. Security risks

| Risk | Severity (local) | Recommendation |
|---|---|---|
| No authentication on product-service and inventory-service APIs | high for any shared environment | CF-065/068 before exposing beyond localhost (OpenAPI declares `security: []` explicitly) |
| Kafka, Kafka UI, Prometheus without authentication | low locally (127.0.0.1 only) | broker auth/ACLs for shared environments (CF-069) |
| `.env.example` contains guessable local passwords | low (local only, documented) | never reuse; secrets manager for shared environments |
| Scripts pass DB passwords as `-e PGPASSWORD=…` (visible in process list) | low locally | use `.pgpass`/secrets in CI |
| `Read(.env)` deny does not cover shell reads | low | add `Bash(cat .env*)`-style deny rules or rely on hook (recommended fix R5) |
| Secret detection is heuristic | medium | add gitleaks in CI (CF-070) |
| OTel Java agent downloaded at image build time | low (checksum-pinned since this audit) | vendor through an internal mirror for shared environments |

## 12. Fixes applied during this audit (safe, non-destructive)

1. Service statuses for product-service and inventory-service updated (`CLAUDE.md`, README).
2. Local PostgreSQL host port aligned to 15432 in 4 Kotlin service configs, 8 READMEs and the `kotlin-springboot` skill.
3. Java version statements in `kotlin-springboot` and `docker-kubernetes` skills aligned to Java 17.
4. `contracts/events/README.md`: envelope table completed (`aggregateType`, `schemaVersion`, `payload`), compatibility policy added, "use by services" corrected (Go does not generate code).
5. Debezium value converter corrected in 7 connectors, the skill, its reference file, ADR-0007, `debezium-design.md` and `infrastructure/README.md`.
6. `contracts/openapi/product-service.v1.yaml` added and linted (Redocly: valid, 2 accepted warnings: local server URL, no license).
7. product-service image: `/otel` directory permissions; Compose health check using `curl` instead of `/dev/tcp`.
8. Code-review fixes in section 8 (UUID validation, rebalance during retries, pinned writer schema, per-record shutdown, SKU ownership, OTel agent checksum, readiness note).
9. Backlog statuses updated with evidence (13 Done, 5 In progress); CF-084 added; dependencies of CF-044/CF-045 narrowed to what the slice actually needed.

No destructive change was made. Nothing was deleted except the earlier, user-approved
build-output cleanup.

## 13. Recommended fixes (not applied)

| ID | Fix | Why not now |
|---|---|---|
| R1 | Add a remote, then CF-020/CF-080 workflows (build, test, compatibility, image per component) | needs the user's remote |
| R2 | CF-040: compatibility check job and negative fixture | new feature work |
| R3 | CF-002: remaining 24 schemas, starting with the saga commands | new feature work |
| R4 | CF-003: decide Go code generation vs. registry-schema decoding | decision for the owner |
| R5 | Extend `permissions.deny` with shell reads of `.env` | configuration change to security policy — proposed, needs approval |
| R7 | Alert rules for DLT arrivals, retries and slot lag (CF-079) | observability phase |
