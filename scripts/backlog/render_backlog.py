"""Renders backlog/*.md from backlog_data.py and validates it.

Usage (from the repository root): python scripts/backlog/render_backlog.py
"""
import sys
from collections import defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import backlog_data as d  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "backlog"
TASKS = {t["id"]: t for t in d.T}
SKILLS = {p.name for p in (ROOT / ".claude/skills").iterdir() if (p / "SKILL.md").exists()}
AGENTS = {p.stem for p in (ROOT / ".claude/agents").glob("*.md")}
ICON = {"Done": "✅ Done", "In progress": "🟡 In progress", "Blocked": "⛔ Blocked", "Not started": "⬜ Not started"}
TODAY = "2026-11-12"

# ------------------------------------------------------------------ validation
errors = []
_seen = set()
for t in d.T:
    if t["id"] in _seen:
        errors.append(f"{t['id']}: duplicate id")
    _seen.add(t["id"])
    for dep in t["deps"]:
        if dep not in TASKS:
            errors.append(f"{t['id']}: unknown dependency {dep}")
        elif TASKS[dep]["phase"] > t["phase"]:
            errors.append(f"{t['id']} (phase {t['phase']}) depends on later-phase {dep} (phase {TASKS[dep]['phase']})")
    for s in t["skills"]:
        if s not in SKILLS:
            errors.append(f"{t['id']}: unknown skill {s}")
    if t["agent"] not in AGENTS:
        errors.append(f"{t['id']}: unknown agent {t['agent']}")
    if t["feature"] not in d.FEATURES:
        errors.append(f"{t['id']}: unknown feature {t['feature']}")
    if t["status"] == "Done" and not t["evidence"]:
        errors.append(f"{t['id']}: Done without evidence")
    if t["status"] == "Done" and any(TASKS[x]["status"] != "Done" for x in t["deps"] if x in TASKS):
        errors.append(f"{t['id']}: Done but a dependency is not Done")
    for field in ("description", "acceptance", "tests", "dod", "owner", "prio"):
        if not t[field]:
            errors.append(f"{t['id']}: empty {field}")
# cycles
state = {}
def visit(n, stack):
    if state.get(n) == 1:
        errors.append("cycle: " + " -> ".join(stack + [n])); return
    if state.get(n) == 2:
        return
    state[n] = 1
    for m in TASKS[n]["deps"]:
        if m in TASKS:
            visit(m, stack + [n])
    state[n] = 2
for n in TASKS:
    visit(n, [])
if errors:
    print("\n".join(errors)); sys.exit(1)

# ready = not done, all deps done
def is_ready(t):
    return t["status"] in ("Not started", "In progress") and all(TASKS[x]["status"] == "Done" for x in t["deps"])

dependents = defaultdict(list)
for t in d.T:
    for dep in t["deps"]:
        dependents[dep].append(t["id"])

def downstream(n, seen=None):
    seen = seen if seen is not None else set()
    for m in dependents[n]:
        if m not in seen:
            seen.add(m); downstream(m, seen)
    return seen

def write(name, text):
    (OUT / name).write_text(text.rstrip() + "\n", encoding="utf-8", newline="\n")
    print("wrote", name)

def link(tid):
    return f"[{tid}](TASKS.md#{tid.lower()})"

by_phase = defaultdict(list)
for t in d.T:
    by_phase[t["phase"]].append(t)
prio_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
counts = defaultdict(int)
for t in d.T:
    counts[t["status"]] += 1
summary = f"{len(d.T)} tasks — " + ", ".join(f"{ICON[s]}: {counts[s]}" for s in ICON)

HEADER = f"""Status legend: ✅ Done = verified in this repository (evidence given) · 🟡 In progress · ⛔ Blocked · ⬜ Not started.
Generated from one data source; IDs `CF-0xx` keep the numbers already used in `docs/`. Snapshot: {TODAY}."""

# ------------------------------------------------------------------ TASKS.md
parts = ["# Tasks", "", HEADER, "", summary, "",
         "Every task also meets the general [Definition of Done](DEFINITION-OF-DONE.md).", ""]
for ph in sorted(by_phase):
    parts += [f"## Phase {ph} — {d.PHASES[ph]}", ""]
    for t in sorted(by_phase[ph], key=lambda x: (prio_order[x["prio"]], x["id"])):
        epic = d.FEATURES[t["feature"]][0]
        parts += [f"### {t['id']}", "", f"**{t['title']}**", "",
                  "| Field | Value |", "|---|---|",
                  f"| Task ID | {t['id']} |",
                  f"| Status | {ICON[t['status']]}{(' — ' + t['evidence']) if t['evidence'] else ''} |",
                  f"| Epic / feature | {epic} / {t['feature']} {d.FEATURES[t['feature']][1]} |",
                  f"| Owning service or application | `{t['owner']}` |",
                  f"| Priority | {t['prio']} |",
                  f"| Dependencies | {', '.join(link(x) for x in t['deps']) or '—'} |",
                  f"| Required agent | `{t['agent']}` |",
                  f"| Required skills | {', '.join('`' + s + '`' for s in t['skills'])} |",
                  "", f"**Description.** {t['description']}", "",
                  "**Acceptance criteria**", ""] + [f"- {a}" for a in t["acceptance"]] + [
                  "", "**Test requirements**", ""] + [f"- {x}" for x in t["tests"]] + [
                  "", "**Definition of Done** — general DoD, plus:", ""] + [f"- {x}" for x in t["dod"]] + [""]
write("TASKS.md", "\n".join(parts))

# ------------------------------------------------------------------ FEATURES.md
parts = ["# Features", "", HEADER, "", "| Feature | Epic | Tasks | Status |", "|---|---|---|---|"]
feat_tasks = defaultdict(list)
for t in d.T:
    feat_tasks[t["feature"]].append(t)
def roll(ts):
    st = {t["status"] for t in ts}
    if st == {"Done"}: return ICON["Done"]
    if "Done" in st or "In progress" in st: return ICON["In progress"]
    if st == {"Blocked"}: return ICON["Blocked"]
    return ICON["Not started"]
for fid, (epic, title) in d.FEATURES.items():
    ts = sorted(feat_tasks[fid], key=lambda x: x["id"])
    parts.append(f"| {fid} {title} | {epic} | {', '.join(link(t['id']) for t in ts)} | {roll(ts)} |")
write("FEATURES.md", "\n".join(parts))

# ------------------------------------------------------------------ EPICS.md
parts = ["# Epics", "", HEADER, "", "| Epic | Goal | Phases | Features | Tasks (done/total) | Status |", "|---|---|---|---|---|---|"]
for eid, (title, goal, phases) in d.EPICS.items():
    fs = [f for f, (e, _) in d.FEATURES.items() if e == eid]
    ts = [t for t in d.T if t["feature"] in fs]
    done = sum(1 for t in ts if t["status"] == "Done")
    parts.append(f"| **{eid}** {title} | {goal} | {', '.join(map(str, phases))} | {', '.join(fs)} | {done}/{len(ts)} | {roll(ts)} |")
for eid, (title, goal, phases) in d.EPICS.items():
    fs = [f for f, (e, _) in d.FEATURES.items() if e == eid]
    parts += ["", f"## {eid} — {title}", "", goal, ""]
    for f in fs:
        parts.append(f"- **{f} {d.FEATURES[f][1]}**: " + ", ".join(f"{link(t['id'])} {t['title']} ({ICON[t['status']]})" for t in sorted(feat_tasks[f], key=lambda x: x['id'])))
write("EPICS.md", "\n".join(parts))

# ------------------------------------------------------------------ DEPENDENCIES.md
crit = []
def longest(n, memo={}):
    if n in memo: return memo[n]
    best = [n]
    for m in TASKS[n]["deps"]:
        p = longest(m) + [n]
        if len(p) > len(best): best = p
    memo[n] = best
    return best
critical = max((longest(n) for n in TASKS), key=len)
lines = ["flowchart LR"]
cls = {"Done": "done", "In progress": "wip", "Blocked": "blocked", "Not started": "todo"}
for ph in sorted(by_phase):
    lines.append(f'    subgraph P{ph}["Phase {ph}: {d.PHASES[ph]}"]')
    for t in sorted(by_phase[ph], key=lambda x: x["id"]):
        if t["id"].startswith("CF-08") and int(t["id"][3:]) >= 84:
            continue
        lines.append(f'        {t["id"].replace("-", "")}["{t["id"]}<br/>{t["title"][:38].replace(chr(34), "")}"]:::{cls[t["status"]]}')
    if ph == 12:
        lines.append('        SVCPIPE["CF-084..CF-093<br/>per-component pipelines (10)"]:::todo')
    lines.append("    end")
for t in d.T:
    tid = t["id"].replace("-", "")
    if t["id"] >= "CF-084" and t["id"] <= "CF-093":
        continue
    for dep in t["deps"]:
        lines.append(f"    {dep.replace('-', '')} --> {tid}")
for dep in ["CF-020", "CF-019", "CF-080", "CF-040", "CF-017"]:
    lines.append(f"    {dep.replace('-', '')} --> SVCPIPE")
lines += ["    classDef done fill:#d1f2d1,stroke:#2e7d32", "    classDef wip fill:#fff4c2,stroke:#b8860b",
          "    classDef blocked fill:#f8d0d0,stroke:#b71c1c", "    classDef todo fill:#eeeeee,stroke:#757575"]
slice_ids = ["CF-005", "CF-037", "CF-002", "CF-003", "CF-043", "CF-044", "CF-038", "CF-045", "CF-046", "CF-052", "CF-053", "CF-055", "CF-048", "CF-057", "CF-010"]
parts = ["# Dependencies", "", HEADER, "",
         "Arrows point from a prerequisite to the task that needs it. Colours: green done, yellow in progress, red blocked, grey not started.",
         "", "```mermaid", *lines, "```", "",
         "## Critical path (longest dependency chain)", "", " → ".join(link(x) for x in critical), "",
         "## Vertical slice first", "",
         "The first end-to-end slice proves the architecture before breadth: product created → outbox → Debezium → Kafka → inventory/pricing consume → order → saga confirmed.",
         "", " → ".join(link(x) for x in slice_ids), "",
         "## Ready to start now (all dependencies done)", "",
         "| Task | Title | Priority | Unblocks (transitively) |", "|---|---|---|---|"]
for t in sorted([t for t in d.T if is_ready(t)], key=lambda x: (prio_order[x["prio"]], -len(downstream(x["id"])), x["id"])):
    parts.append(f"| {link(t['id'])} | {t['title']} | {t['prio']} | {len(downstream(t['id']))} tasks |")
parts += ["", "## Blocked", ""]
for t in [t for t in d.T if t["status"] == "Blocked"]:
    parts.append(f"- {link(t['id'])} {t['title']} — {t['evidence']}")
parts += ["", "## Contract dependencies (monorepo rule)", "",
          "- Any change in `contracts/events` must pass [CF-040](TASKS.md#cf-040) compatibility checks and trigger the pipelines of every producer and consumer ([CF-080](TASKS.md#cf-080)).",
          "- Provider APIs consumed by apps or services are gated by Pact ([CF-017](TASKS.md#cf-017)) before deployment ([CF-084..CF-093](TASKS.md#phase-12--kubernetes-and-production-readiness)).",
          "- Producer and consumer of one event are separate tasks and deploy separately: consumers first for additive changes (`docs/event-catalog/event-versioning-policy.md`)."]
write("DEPENDENCIES.md", "\n".join(parts))

# ------------------------------------------------------------------ ROADMAP.md
goals = {
    1: "One repository, documented architecture, every component builds on its own.",
    2: "Claude works safely: agents, skills, workflows and guardrail hooks.",
    3: "Local stack with per-service databases, Kafka, Debezium and observability, verified healthy; CDC verified end to end.",
    4: "**Vertical slice part 1**: product created via API reaches Kafka through outbox + Debezium with valid Avro; contract compatibility checks exist.",
    5: "Inventory and pricing consume product events idempotently; customer profile exists.",
    6: "Orders can be created against a quote; payment handles authorization and void.",
    7: "**Vertical slice part 2**: order saga confirms, compensates and times out correctly; shipping and notifications react.",
    8: "Staff manage catalog, prices and orders through the admin BFF with real identity.",
    9: "Customers browse, check out and track orders.",
    10: "All test layers in place: architecture, contract, integration, E2E, performance baselines, resilience.",
    11: "Tracing across async hops, dashboards, alerts, SLOs; security scanning and audits.",
    12: "Per-component CI/CD, Helm/Kubernetes, Terraform, DR and retention ready for a first environment.",
}
parts = ["# Roadmap", "", HEADER, "", summary, "",
         "Phases are ordered by dependency, not by calendar; no dates are committed. The vertical slice (phases 3–7) is prioritised over breadth.", "",
         "| Phase | Goal | Tasks | Done | Status |", "|---|---|---|---|---|"]
for ph in sorted(by_phase):
    ts = by_phase[ph]
    parts.append(f"| {ph}. {d.PHASES[ph]} | {goals[ph]} | {len(ts)} | {sum(1 for t in ts if t['status']=='Done')} | {roll(ts)} |")
for ph in sorted(by_phase):
    parts += ["", f"## Phase {ph} — {d.PHASES[ph]}", "", goals[ph], "",
              "| Task | Title | Owner | Priority | Status |", "|---|---|---|---|---|"]
    for t in sorted(by_phase[ph], key=lambda x: (prio_order[x["prio"]], x["id"])):
        parts.append(f"| {link(t['id'])} | {t['title']} | `{t['owner']}` | {t['prio']} | {ICON[t['status']]} |")
ready = sorted([t for t in d.T if is_ready(t)], key=lambda x: (prio_order[x["prio"]], -len(downstream(x["id"])), x["id"]))
parts += ["", "## Recommended next executable task", "",
          "1. **[CF-005](TASKS.md#cf-005) — finish verifying the local stack** (files are written; the first start was interrupted by a Docker Engine error). Restart Docker Desktop, then `infrastructure/scripts/up.ps1` and `health.ps1`. It unblocks "
          f"{len(downstream('CF-005'))} tasks, including the CDC verification [CF-037](TASKS.md#cf-037).",
          "2. In parallel, without Docker: **[CF-002](TASKS.md#cf-002) — v1 Avro schemas** (`/create-domain-event`, agent `event-driven-engineer`). It is P0, all its dependencies are done, and it unblocks "
          f"{len(downstream('CF-002'))} tasks on the vertical slice.",
          "3. Then **[CF-003](TASKS.md#cf-003)** (codegen) and **[CF-043](TASKS.md#cf-043)** (product API) to complete phase 4 inputs.", "",
          "Also ready: " + ", ".join(link(t["id"]) for t in ready if t["id"] not in ("CF-005", "CF-002", "CF-003", "CF-043")) + "."]
write("ROADMAP.md", "\n".join(parts))

# ------------------------------------------------------------------ MILESTONES.md
ms = [
    ("M1", "Foundation complete", [1, 2], "Monorepo, docs, scaffolds, Claude framework verified"),
    ("M2", "Local platform verified", [3], "health.ps1 green and verify-cdc.ps1 passes"),
    ("M3", "Vertical slice: product CDC", [4], "Product created via API arrives on Kafka with valid Avro; compatibility checks run"),
    ("M4", "Downstream projections", [5], "Inventory and pricing consume product events idempotently"),
    ("M5", "Orders and payments", [6], "Order creation with quote; payment authorization/void handlers"),
    ("M6", "Vertical slice: saga", [7], "Order saga happy path, compensation and timeouts verified on Compose"),
    ("M7", "Admin usable", [8], "Staff manage catalog, prices and orders with real login"),
    ("M8", "Storefront usable", [9], "Customer browse → checkout → order status"),
    ("M9", "Quality gates", [10], "All test layers in CI or nightly"),
    ("M10", "Operable and secure", [11], "Traces/dashboards/alerts/SLOs, scanning, audit with no open high findings"),
    ("M11", "Production ready", [12], "Per-component pipelines, Helm/Kubernetes, DR and retention"),
]
parts = ["# Milestones", "", HEADER, "", "| Milestone | Phases | Exit criteria | Tasks done/total | Status |", "|---|---|---|---|---|"]
for mid, title, phs, crit_txt in ms:
    ts = [t for ph in phs for t in by_phase[ph]]
    parts.append(f"| **{mid}** {title} | {', '.join(map(str, phs))} | {crit_txt} | {sum(1 for t in ts if t['status']=='Done')}/{len(ts)} | {roll(ts)} |")
parts += ["", "A milestone is reached only when every task in its phases is ✅ Done with evidence. No milestone is reached yet: M1 has open items",
          " (" + ", ".join(link(t['id']) for ph in (1, 2) for t in by_phase[ph] if t['status'] != 'Done') + ")."]
write("MILESTONES.md", "\n".join(parts))

print(summary)
print("critical path length:", len(critical))
print("ready:", ", ".join(t["id"] for t in ready))
