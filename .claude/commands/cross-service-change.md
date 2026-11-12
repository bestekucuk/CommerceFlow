---
description: Plan a change that spans several CommerceFlow services as ordered, independently deployable steps
argument-hint: <backlog-id> <short description of the change>
---

Plan this change: $ARGUMENTS

1. Read the root `CLAUDE.md`, `docs/architecture/overview.md` and
   `docs/event-catalog/README.md`.
2. Identify every affected service, app and contract, and why.
3. Produce an ordered list of steps. Each step names the folder(s) it changes and why the
   system still works when only the steps so far are deployed — services deploy
   separately even though they share this repository. Contract changes come first;
   consumers before producers for additive changes.
4. Say which steps can share a commit and which must be separate commits.
5. Flag any step that needs an ADR, a schema version bump or a data migration.
6. Stop and present the plan. Do not edit files until the user approves.
