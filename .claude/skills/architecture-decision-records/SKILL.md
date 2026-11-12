---
name: architecture-decision-records
description: Write, update and supersede Architecture Decision Records in docs/adr for CommerceFlow - numbering, template, statuses, alternatives and consequences, and keeping the ADR index current. Use for any decision that affects more than one service, a shared contract or platform component, or is expensive to reverse.
---

# Architecture Decision Records

## Purpose

Record why CommerceFlow is built the way it is, so later changes can be judged against the
original forces instead of guessed. ADRs live in `docs/adr/` and are owned by the
`commerce-architect` agent; only the user accepts them.

## When to use

- A service boundary, data owner or integration style changes.
- A technology, library or platform component is chosen or replaced.
- A cross-cutting convention is introduced (topic naming, auth model, build tooling).
- An existing ADR no longer holds.

Not needed for decisions local to one service that are cheap to reverse.

## Prerequisites

- Read `docs/adr/README.md` and existing ADRs (especially 0002–0004).
- Know the backlog item driving the decision (`backlog/BACKLOG.md`).

## Concepts and architecture

Statuses: `Proposed` → `Accepted` (user only) → optionally `Deprecated` or
`Superseded by NNNN`. ADRs are immutable once accepted except for the status line and
links; a changed decision is a new ADR that supersedes the old one.

Structure (`docs/adr/0000-template.md`): Context, Decision, Alternatives considered,
Consequences, plus metadata (status, date, deciders, affected areas).

## Step-by-step workflow

1. List `docs/adr/` and take the next free four-digit number.
2. Copy `0000-template.md` to `NNNN-kebab-case-title.md`.
3. **Context**: forces, constraints, the problem in a few paragraphs. Facts, not the answer.
4. **Decision**: active voice, specific ("Services publish events via a transactional
   outbox read by Debezium").
5. **Alternatives**: at least two, each with why it was rejected.
6. **Consequences**: positive, negative, follow-up work with backlog IDs.
7. Set status `Proposed`, date today, affected areas as repo paths.
8. If superseding: set the old ADR's status to `Superseded by [NNNN](NNNN-....md)` and add
   `Supersedes:` to the new one.
9. Update the index table in `docs/adr/README.md`.
10. Add backlog items for follow-ups.

## Practical code examples

```markdown
# 0005. Avro payloads are serialized by services and passed through by Debezium

- Status: Proposed
- Date: 2026-11-20
- Deciders: project owner, commerce-architect
- Affected areas: `services/*/adapters/out/messaging`, `infrastructure/debezium`, `contracts/events`

## Context

Contracts are Avro schemas in `contracts/events/`. Debezium can either infer a schema from
a JSON outbox payload or pass bytes through unchanged. Inferred schemas would not match the
reviewed contracts and would bypass compatibility checks.

## Decision

Each service serializes outbox payloads with the registered Avro schema (Confluent wire
format) into a `bytea` column. The Debezium connector uses a byte-array value converter so
the bytes reach Kafka unchanged.

## Alternatives considered

- JSON payload + `table.expand.json.payload` — schema drift from contracts; no registry checks.
- Publishing from the application after commit — dual-write problem (ADR-0002).

## Consequences

- Services need a Schema Registry client at runtime (serialization) — CF-024.
- Payloads are not human-readable in the database; add a debug decoder script (CF-025).
```

Index row:

```markdown
| [0005](0005-avro-payloads-passed-through-by-debezium.md) | Avro payloads serialized by services | Proposed |
```

## Recommended project structure

```text
docs/adr/
  README.md             index (number, title, status)
  0000-template.md
  NNNN-kebab-title.md
```

## Best practices

- One decision per ADR.
- Write the ADR before or with the change, not after.
- Link ADRs from code comments only where the reason is non-obvious.
- Keep it short: one to two pages.
- Quantify where possible (latency budget, team size, expected throughput).

## Anti-patterns

- Editing an accepted ADR's decision instead of superseding it.
- ADRs without alternatives ("we chose X").
- Marking your own ADR `Accepted`.
- Recording implementation details that belong in a service README.

## Failure scenarios

| Scenario | Handling |
|---|---|
| Two ADRs contradict | Newer one must explicitly supersede; fix status lines. |
| Decision made in chat but not recorded | Write the ADR now with the real date of the decision. |
| ADR references removed paths | Update the "Affected areas" line only; do not rewrite history. |

## Testing strategy

ADRs are documents; verify by checklist: number unique, index updated, links resolve
(`ls` each linked file), status valid, alternatives ≥ 2.

## Definition of Done

- File named `NNNN-kebab-title.md` with the next free number.
- All template sections filled; at least two alternatives.
- Status `Proposed` (unless the user accepted it).
- Index updated; superseded ADRs updated.
- Follow-up backlog items created.
