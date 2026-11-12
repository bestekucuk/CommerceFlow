# Hook Catalog

Claude Code hooks for CommerceFlow. Configuration: `.claude/settings.json` (`hooks`
section). Scripts: `.claude/hooks/*.ps1` with shared helpers in `.claude/hooks/lib/common.ps1`.
Tests: `.claude/hooks/tests/Test-Hooks.ps1`.

All hooks are **deterministic**: fixed regular expressions and git queries, no network,
no randomness, no AI judgement. They never modify source files. Only
`track-test-debt.ps1` writes state, in `.claude/hooks/.state/` (gitignored, per session).

## Runtime

- Command form: `powershell -NoProfile -ExecutionPolicy Bypass -File "$CLAUDE_PROJECT_DIR/.claude/hooks/<hook>.ps1"`
  (Windows PowerShell 5.1+; also works with `pwsh` if `powershell` is aliased).
- Input: the hook event JSON on stdin (UTF-8; a BOM is tolerated).
- Culture-invariant matching is forced (`InvariantCulture`): under `tr-TR`,
  case-insensitive regex treats `I` as dotless `ı` and would silently miss matches.
- Each hook invocation starts a PowerShell process (~0.3–1 s on this machine).
- Claude Code loads hook configuration at session start; after editing `settings.json`,
  review hooks with the `/hooks` menu in an interactive terminal or restart the session.

## Overview

| Hook script | Event | Matcher | Purpose | Effect |
|---|---|---|---|---|
| `guard-destructive-commands.ps1` | PreToolUse | `Bash\|PowerShell` | Destructive command protection | `deny` or `ask` decision |
| `detect-secrets.ps1` | PreToolUse | `Write\|Edit\|MultiEdit\|NotebookEdit` and `Bash\|PowerShell` (`git commit`) | Accidental secret detection | `deny` decision |
| `check-formatting.ps1` | PostToolUse | `Write\|Edit\|MultiEdit` | Formatting validation | feedback to Claude (exit 2) |
| `track-test-debt.ps1` | PostToolUse | `Write\|Edit\|MultiEdit` and `Bash\|PowerShell` | Records edits and test runs per component | state only |
| `remind-tests.ps1` | Stop | — | Test execution reminder | `block` once (Claude continues) |
| `check-architecture-docs.ps1` | Stop | — | Architecture documentation checks | `block` once (Claude continues) |

PreToolUse decisions use `hookSpecificOutput.permissionDecision` (`deny` stops the call and
tells Claude why; `ask` shows the user a confirmation). Stop hooks return
`{"decision":"block","reason":...}` and skip when `stop_hook_active` is true, so they nudge
at most once per stop and cannot loop.

Settings `permissions.deny` additionally blocks `git push`, remote changes, `gh pr merge`,
`terraform apply/destroy`, `helm install/upgrade`, `kubectl apply/delete` and reading `.env`
files — a second, independent layer.

## guard-destructive-commands.ps1

First matching rule wins.

| Decision | Rule | Examples |
|---|---|---|
| deny | git push / remote add, set-url, remove | `git push`, `git -C x push`, `git remote add origin …` |
| deny | PR merge | `gh pr merge`, `gh api …/merge` |
| deny | deployments | `kubectl apply/create/delete/replace/patch/scale/rollout restart/drain`, `helm install/upgrade/uninstall/rollback`, `terraform apply/destroy/import/state rm`, `docker push`, `gh workflow run`, `gh release create` |
| deny | destructive migrations | `flyway clean/repair/undo`, `gradlew flywayClean…`, `migrate … down/drop/force` |
| deny | destructive SQL via a client | `psql … DROP DATABASE/SCHEMA/TABLE/ROLE/PUBLICATION`, `TRUNCATE`, `DELETE FROM x` without `WHERE`, `pg_drop_replication_slot` |
| ask | recursive/forced delete | `rm -rf`, `Remove-Item -Recurse` |
| ask | discarding git work/history | `git reset --hard`, `git clean -f`, `git checkout -- …`, `git restore .`, `git branch -D`, `git stash drop/clear`, `filter-branch`, `filter-repo`, `rebase`, `commit --amend` |
| ask | removing Docker data | `docker compose down -v`, `docker volume rm/prune`, `docker system prune` |

Allowed examples: `git status`, `git log --grep push`, `git commit -m "…push…"`,
`terraform plan`, `docker compose down`, `kubectl get`, `helm lint`, `DELETE … WHERE …`.

## detect-secrets.ps1

| Check | Detail |
|---|---|
| Patterns | private key blocks; AWS key IDs (`AKIA…`/`ASIA…`); GitHub tokens (`ghp_`, `github_pat_`, …); Slack tokens (`xox?-`); Stripe live keys; Google API keys; JWTs; credentials in URLs (`scheme://user:pass@host`); `password/secret/api_key/token/... = value` where the value is ≥ 12 chars, contains a digit and is not a `${VAR}`/`{{ }}`/`<…>` reference or an obvious placeholder |
| Writes | Scans `content`, `new_string`, every `edits[].new_string`, `new_source` before the write. Blocks writing `.env`/`.env.*` files except `.env.example`. |
| Commits | For `git commit` commands: added lines of `git diff HEAD` plus all untracked files (so `git add -A && git commit` is covered). Files > 1 MB skipped. |
| Escape hatch | A line containing `secret-scan:allow` is skipped — only for documented, fake test fixtures. |
| Known limits | Heuristic: letters-only passwords and secrets split across lines are not detected. CI should also run `gitleaks` (`security-review`). |

## check-formatting.ps1

Runs on the file just written; reports problems to Claude (exit 2), never rewrites files.

| Check | Applies to |
|---|---|
| Final newline; no merge-conflict markers | all text files |
| No trailing whitespace | all but Markdown |
| No tab indentation | `.yml`, `.yaml` |
| Valid JSON | `.json` |
| Frontmatter starts on line 1, is closed, `name` equals directory/file name, has `description` | `.claude/skills/*/SKILL.md`, `.claude/agents/*.md` |
| `gofmt -l` | `.go`, if `gofmt` is installed |
| `ktlint` | `.kt`, `.kts`, if `ktlint` is installed |
| app-local `prettier --check` | `apps/<app>/**/*.ts(x)/.css`, if the app has prettier installed |

Missing formatters are skipped silently, so results depend only on installed tooling.

## track-test-debt.ps1 and remind-tests.ps1

- An edit to a non-Markdown file under `services/<x>/` or `apps/<x>/` adds that component
  to the session's test debt.
- A successful test/build command naming the component (`services/<x>` / `apps/<x>` in the
  command, or run from inside it) clears it: `gradlew build|test|check|integrationTest`,
  `go test`, `make test|check`, `npm test`, `vitest run`, `npx playwright test`. A response
  with a non-zero exit code keeps the debt.
- At Stop, remaining debt makes Claude run those tests or state why they cannot run (e.g.
  "no build file yet"). Suggested command per component is included.

## check-architecture-docs.ps1

Inspects only uncommitted changes (`git status`), so existing state never nags.

| Rule | Condition | Required |
|---|---|---|
| A1 | `contracts/events/**` changed | `docs/event-catalog/README.md` changed too |
| A2 | files under `services/<x>` or `apps/<x>` changed | component listed in `docs/architecture/service-catalog.md` |
| A3 | `.claude/agents/<x>.md` changed | listed in `docs/agent-catalog.md` |
| A4 | `.claude/skills/<x>/` changed | listed in `docs/skill-catalog.md` or `docs/workflow-catalog.md` |
| A5 | `.claude/hooks/<x>.ps1` changed | documented here |
| A6 | `docs/adr/NNNN-*.md` changed | listed in `docs/adr/README.md` |
| A7 | Kotlin import of another service's package (`com.commerceflow.<other context>`), Go import of another service module, or `replace ../` in `go.mod` | none allowed |

## What hooks never do

Push, merge, deploy, delete data, run migrations, install tools, call the network, or
edit source files. Workflows that need such actions leave them to the user.

## Testing the hooks

```bash
powershell -NoProfile -ExecutionPolicy Bypass -File .claude/hooks/tests/Test-Hooks.ps1
```

The suite feeds recorded-style JSON payloads to each hook (allowed and blocked cases,
including a Turkish-`I` regression), uses throwaway git repositories under `%TEMP%`, and
scans every tracked file for false positives. Fake secrets are assembled at runtime so the
test file itself contains none.
