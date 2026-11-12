# scripts

Repository-level helper scripts (CF-021). Each one calls a component's **own** build;
nothing compiles components together. Details and verification: `docs/service-catalog.md`.

| Script | Status | Purpose |
|---|---|---|
| `affected-components.ps1 [base] [-Json]` | implemented | Components affected by changes, including consumers of changed contracts |
| `build-service.ps1 <name> [-Image]` | implemented | Build one service/app (and its Docker image) |
| `test-service.ps1 <name> [-Integration]` | implemented | Test one service/app (Testcontainers / Playwright with `-Integration`) |
| `build-all.ps1 [-Image]` | implemented | Build every component one by one; continues after failures |
| `test-all.ps1 [-Integration]` | implemented | Test every component one by one |
| `lib/components.ps1` | implemented | Shared helpers (component discovery, Go-in-Docker fallback) |
| infra up/down/health/migrate/connectors/verify-cdc | implemented | In `infrastructure/scripts/` (see `infrastructure/README.md`) |
