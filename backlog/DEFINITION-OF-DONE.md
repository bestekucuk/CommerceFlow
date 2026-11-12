# Definition of Done

A task is **Done** only when everything below that applies to it is true **and verified**
(commands actually run, results recorded). "Implemented but not run" is *In progress*.
Task-specific additions are listed in each task in [TASKS.md](TASKS.md).

## General (every task)

- [ ] Acceptance criteria of the task are met and demonstrated.
- [ ] Changes stay inside the owning folder(s); cross-service work followed an architect
      plan (`/implement-feature`).
- [ ] Each touched component builds and its tests pass **from its own folder**
      (`scripts/build-service.ps1`, `scripts/test-service.ps1`).
- [ ] Independent review by `code-reviewer` (`/code-review`) with verdict *approve* or
      *approve with comments*; blocking/major findings resolved.
- [ ] Documentation updated in the same change (README/CLAUDE.md of the component,
      catalogues, ADR when a decision was made). The Stop hook `check-architecture-docs`
      reports no drift.
- [ ] No secrets, personal data or production credentials committed (secret hook clean).
- [ ] Backlog status updated with evidence (command, result, date or commit).
- [ ] Nothing pushed, merged or deployed by Claude; the user does that.

## Code in a service

- [ ] Clean Architecture holds: domain free of framework imports (ArchUnit / Go import test).
- [ ] Unit tests for every new invariant (allowed and rejected case).
- [ ] Adapter changes covered by Testcontainers integration tests.
- [ ] Every event published through the outbox in the business transaction.
- [ ] Every consumer idempotent (inbox) with retry/DLT policy and duplicate-delivery test.
- [ ] Migrations backward compatible with the running version (`/database-migration-review`).
- [ ] Endpoints authenticated and authorized at function and object level, with negative
      tests (once identity exists, CF-065/CF-068).
- [ ] Trace context propagated (once CF-012 is done).

## Contract changes (`contracts/`)

- [ ] Change classified (additive / breaking); breaking → new major version.
- [ ] Compatibility check passes (CF-040) and the event catalogue is updated.
- [ ] Rollout order documented: consumers before producers for additive changes.
- [ ] Every affected producer and consumer pipeline ran (CF-080).

## Frontend

- [ ] TypeScript strict passes; no `any` in API types.
- [ ] API calls through generated clients, covered by Pact consumer tests.
- [ ] Loading, empty and error states; keyboard accessible; labelled controls.
- [ ] Relevant Playwright journey passes (`/run-e2e`).

## Infrastructure and pipelines

- [ ] Validation commands pass (`docker compose config`, `helm lint`, `terraform validate`,
      `actionlint`, `promtool`) as applicable.
- [ ] Health checks verified on a real run; results in the component README's verification log.
- [ ] Credentials only through environment/secret stores; local-only values clearly marked.
- [ ] One pipeline per component with path filters including consumed contracts.

## Decisions

- [ ] ADR written with at least two alternatives; status set by the project owner.

## Security-relevant changes

Authentication, authorization, secrets, payment, personal data, public endpoints or
infrastructure exposure additionally need `/security-audit` with no open critical or high
findings.
