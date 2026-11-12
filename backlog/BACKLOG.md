# Engineering Backlog — index

The backlog is split into planning views generated from one task list:

| File | Content |
|---|---|
| [ROADMAP.md](ROADMAP.md) | 12 delivery phases, status per phase, **recommended next task** |
| [MILESTONES.md](MILESTONES.md) | Milestones M1–M11 with exit criteria |
| [EPICS.md](EPICS.md) | CF-EPIC-01 … CF-EPIC-18 with features and tasks |
| [FEATURES.md](FEATURES.md) | Features F-01 … F-30 |
| [TASKS.md](TASKS.md) | Every task with owner, priority, dependencies, acceptance criteria, agent, skills, tests and DoD |
| [DEPENDENCIES.md](DEPENDENCIES.md) | Mermaid dependency graph, critical path, vertical slice, ready tasks |
| [DEFINITION-OF-DONE.md](DEFINITION-OF-DONE.md) | General and type-specific Definition of Done |

## Rules

- IDs `CF-0xx` are stable and referenced from `docs/`; reference them in commit messages.
- A task is ✅ Done only with evidence (command and result, date or commit).
- Status changes are made in the task list and all views are regenerated together.
- Decision tasks (CF-001, CF-004, CF-014, CF-015, CF-016, CF-025, CF-026, CF-027) are
  resolved by the project owner; agents prepare ADRs.

## Retired IDs

| Old ID | Replaced by |
|---|---|
| CF-006 (order-service beyond scaffold) | CF-055, CF-056, CF-010 |
| CF-007 (inventory-service beyond scaffold) | CF-046, CF-048 |
| CF-008 (Kotlin services beyond scaffold) | CF-043, CF-050, CF-052, CF-057 and per-service tasks |
| CF-009 (Go services beyond scaffold) | CF-060, CF-063 |
| CF-013 (web apps beyond scaffold) | CF-064, CF-073, CF-074 |
| CF-028 (payment capture timing, delivery address) | CF-016 (capture) and the event-catalogue open point (address) |
