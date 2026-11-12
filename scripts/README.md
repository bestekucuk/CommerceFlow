# scripts

Status: **one script implemented**, the rest planned. Repository-level helper scripts (CF-021):

- `affected-components.ps1` (done) — list services and apps changed since a git ref, including
  services that consume a changed contract.
- `build <service>` / `test <service>` — run one service's own build from the root.
- `dev-up` / `dev-down` — start and stop the local stack.

Scripts call each service's own build; they never compile services together.
