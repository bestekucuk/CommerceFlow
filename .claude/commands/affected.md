---
description: List which services and apps are affected by changes since a git ref (default HEAD, i.e. uncommitted changes)
argument-hint: [git-ref]
---

Base ref: `$ARGUMENTS` (use `HEAD` if empty).

1. Collect changed paths: `git diff --name-only <ref>` plus untracked files from
   `git status --porcelain`.
2. Map each path to a component:
   - `services/<name>/...` → that service
   - `apps/<name>/...` → that app
   - `contracts/events/...` → every producer and consumer of the changed events, from
     `docs/event-catalog/README.md`
   - `contracts/openapi/<service>...` → that service and the apps that call it
   - `infrastructure/`, `docker-compose.yml`, `tests/`, `docs/`, `.claude/` → report as
     "platform"
3. Present a table: component, why affected, changed files count.
4. Flag any single change set touching more than one service and remind that they deploy
   separately. Do not modify anything.
