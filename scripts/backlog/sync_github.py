"""Mirrors the backlog (backlog_data.py) to GitHub: labels, one issue per epic and task,
epics as parent issues (sub-issues), and a GitHub Project board with Status, Agent,
Phase, Priority and Epic fields.

Idempotent: issues are matched by their "[CF-...]" title prefix, so a rerun updates
titles, bodies, labels, open/closed state and board fields instead of creating
duplicates. backlog_data.py stays the source of truth; edit it, rerun the renderer and
this script.

Requires the GitHub CLI logged in with the "project" scope
(gh auth refresh -s project).

Usage (from the repository root):
  python scripts/backlog/sync_github.py --dry-run
  python scripts/backlog/sync_github.py
"""
import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import backlog_data as d  # noqa: E402

REPO = "bestekucuk/CommerceFlow"
OWNER = "bestekucuk"
PROJECT_TITLE = "CommerceFlow Backlog"
TASKS_URL = f"https://github.com/{REPO}/blob/main/backlog/TASKS.md"
STATUS = {"Done": "Done", "In progress": "In Progress", "Blocked": "Todo", "Not started": "Todo"}
PAUSE = 1.0  # seconds between content-creating calls (GitHub secondary rate limits)

GH = shutil.which("gh") or r"C:\Program Files\GitHub CLI\gh.exe"
DRY = False


def gh(*args, json_out=False, write=False, check=True):
    if DRY and write:
        print("  [dry-run] gh", " ".join(a if len(a) < 60 else a[:57] + "..." for a in args))
        return {} if json_out else ""
    r = subprocess.run([GH, *args], capture_output=True, text=True, encoding="utf-8")
    if check and r.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:3])} failed: {r.stderr.strip()}")
    if write:
        time.sleep(PAUSE)
    if json_out:
        return json.loads(r.stdout) if r.stdout.strip() else {}
    return r.stdout


# ------------------------------------------------------------------ model
def epic_of(task):
    return d.FEATURES[task["feature"]][0]


def labels_for_task(t):
    out = ["type:task", f"phase:{t['phase']}", f"priority:{t['prio']}", f"agent:{t['agent']}"]
    if t["id"] in d.MVP:
        out.append("mvp")
    if t["status"] == "Blocked":
        out.append("blocked")
    return out


def all_labels():
    want = {"type:epic": ("5319e7", "Epic: a group of related tasks"),
            "type:task": ("1d76db", "Backlog task"),
            "mvp": ("d93f0b", "Part of the MVP (basic sales flow)"),
            "blocked": ("b60205", "Blocked by an external decision or dependency")}
    for p, name in d.PHASES.items():
        want[f"phase:{p}"] = ("c5def5", f"Phase {p}: {name}")
    for prio in ("P0", "P1", "P2", "P3"):
        want[f"priority:{prio}"] = ({"P0": "b60205", "P1": "fbca04", "P2": "0e8a16", "P3": "bfdadc"}[prio], f"Priority {prio}")
    for agent in sorted({t["agent"] for t in d.T}):
        want[f"agent:{agent}"] = ("006b75", f"Owned by the {agent} agent")
    return want


def task_body(t, numbers):
    def ref(i):
        return f"#{numbers[i]}" if i in numbers else i
    check = "x" if t["status"] == "Done" else " "
    lines = [
        f"> Generated from `scripts/backlog/backlog_data.py` — edit there, not here. Details: [{t['id']}]({TASKS_URL}#{t['id'].lower()})",
        "",
        "| | |", "|---|---|",
        f"| Epic | {ref(epic_of(t))} {d.EPICS[epic_of(t)][0]} |",
        f"| Feature | {t['feature']} {d.FEATURES[t['feature']][1]} |",
        f"| Phase | {t['phase']}. {d.PHASES[t['phase']]} |",
        f"| Priority | {t['prio']} |",
        f"| Status | {t['status']} |",
        f"| Owner (path) | `{t['owner']}` |",
        f"| Agent | `{t['agent']}` |",
        f"| Skills | {', '.join('`' + s + '`' for s in t['skills'])} |",
        f"| MVP | {'yes' if t['id'] in d.MVP else 'no'} |",
        f"| Depends on | {', '.join(ref(x) for x in t['deps']) or '—'} |",
        "", "## Description", "", t["description"],
        "", "## Acceptance criteria", "", *[f"- [{check}] {a}" for a in t["acceptance"]],
        "", "## Tests", "", *[f"- {x}" for x in t["tests"]],
        "", "## Definition of done (task specific)", "", *[f"- {x}" for x in t["dod"]],
    ]
    if t["evidence"]:
        lines += ["", "## Evidence", "", t["evidence"]]
    return "\n".join(lines) + "\n"


def epic_body(eid, numbers):
    name, desc, phases = d.EPICS[eid]
    tasks = [t for t in d.T if epic_of(t) == eid]
    done = sum(t["status"] == "Done" for t in tasks)
    lines = [
        f"> Generated from `scripts/backlog/backlog_data.py`. Tasks are linked as sub-issues.",
        "", desc, "",
        f"Phases: {', '.join(f'{p}. {d.PHASES[p]}' for p in phases)} · Tasks done: {done}/{len(tasks)}",
        "", "## Tasks", "",
        *[f"- [{'x' if t['status'] == 'Done' else ' '}] {('#' + str(numbers[t['id']])) if t['id'] in numbers else t['id']} {t['title']}"
          + (" · MVP" if t["id"] in d.MVP else "") for t in tasks],
    ]
    return "\n".join(lines) + "\n"


# ------------------------------------------------------------------ issues
def existing_issues():
    out = gh("issue", "list", "--repo", REPO, "--state", "all", "--limit", "1000",
             "--json", "number,title,state,id,labels", json_out=True) or []
    found = {}
    for i in out:
        if i["title"].startswith("[CF-"):
            found[i["title"][1:].split("]")[0]] = i
    return found


def ensure_labels():
    have = {l["name"] for l in gh("label", "list", "--repo", REPO, "--limit", "500", "--json", "name", json_out=True) or []}
    for name, (color, desc) in all_labels().items():
        if name not in have:
            gh("label", "create", name, "--repo", REPO, "--color", color, "--description", desc, write=True)
    print(f"labels: {len(all_labels())} ensured")


def upsert_issue(key, title, body, labels, closed, found, numbers):
    title = f"[{key}] {title}"
    if key in found:
        n = found[key]["number"]
        managed = ("type:", "phase:", "priority:", "agent:", "mvp", "blocked")
        stale = [l["name"] for l in found[key].get("labels", [])
                 if l["name"].startswith(managed) and l["name"] not in labels]
        gh("issue", "edit", str(n), "--repo", REPO, "--title", title, "--body", body,
           *sum((["--add-label", l] for l in labels), []),
           *sum((["--remove-label", l] for l in stale), []), write=True)
        state = found[key]["state"]
    else:
        url = gh("issue", "create", "--repo", REPO, "--title", title, "--body", body,
                 *sum((["--label", l] for l in labels), []), write=True).strip()
        n = int(url.rsplit("/", 1)[-1]) if url else -1
        state = "OPEN"
        print(f"  created {key} -> #{n}")
    numbers[key] = n
    if closed and state == "OPEN":
        gh("issue", "close", str(n), "--repo", REPO, "--reason", "completed", write=True)
    elif not closed and state == "CLOSED":
        gh("issue", "reopen", str(n), "--repo", REPO, write=True)
    return n


def link_sub_issues(numbers):
    """Epic -> task parent links (GitHub sub-issues). Already-linked pairs are skipped."""
    if DRY:
        print(f"  [dry-run] would link {len(d.T)} tasks under their epics")
        return
    ids = {}
    for key, n in numbers.items():
        ids[key] = gh("api", f"repos/{REPO}/issues/{n}", "--jq", ".id").strip()
    linked = 0
    for eid in d.EPICS:
        current = {i["number"] for i in gh("api", f"repos/{REPO}/issues/{numbers[eid]}/sub_issues?per_page=100", json_out=True) or []}
        for t in d.T:
            if epic_of(t) != eid or numbers[t["id"]] in current:
                continue
            gh("api", "-X", "POST", f"repos/{REPO}/issues/{numbers[eid]}/sub_issues",
               "-F", f"sub_issue_id={ids[t['id']]}", write=True)
            linked += 1
    print(f"sub-issues: {linked} new links")


# ------------------------------------------------------------------ project board
def ensure_project():
    projects = gh("project", "list", "--owner", OWNER, "--format", "json", json_out=True).get("projects", [])
    p = next((p for p in projects if p["title"] == PROJECT_TITLE), None)
    if not p:
        if DRY:
            print(f"  [dry-run] would create project '{PROJECT_TITLE}'")
            return None
        p = gh("project", "create", "--owner", OWNER, "--title", PROJECT_TITLE, "--format", "json", json_out=True, write=True)
        gh("project", "link", str(p["number"]), "--owner", OWNER, "--repo", REPO, write=True, check=False)
        print(f"project created: #{p['number']}")
    return p


def ensure_fields(pnum):
    wanted = {
        "Agent": sorted({t["agent"] for t in d.T}),
        "Phase": [f"{p}. {n}" for p, n in d.PHASES.items()],
        "Priority": ["P0", "P1", "P2", "P3"],
        "Epic": [f"{k[-2:]} {v[0]}" for k, v in d.EPICS.items()],
        "MVP": ["Yes", "No"],
    }
    fields = gh("project", "field-list", str(pnum), "--owner", OWNER, "--format", "json", "--limit", "50", json_out=True)["fields"]
    names = {f["name"] for f in fields}
    for name, options in wanted.items():
        if name not in names:
            gh("project", "field-create", str(pnum), "--owner", OWNER, "--name", name,
               "--data-type", "SINGLE_SELECT", "--single-select-options", ",".join(options), write=True)
    fields = gh("project", "field-list", str(pnum), "--owner", OWNER, "--format", "json", "--limit", "50", json_out=True)["fields"]
    return {f["name"]: {"id": f["id"], "options": {o["name"]: o["id"] for o in f.get("options", [])}} for f in fields}


def sync_board(numbers):
    p = ensure_project()
    if not p:
        return
    pnum, pid = p["number"], p["id"]
    fields = ensure_fields(pnum)
    status_opts = fields["Status"]["options"]
    missing = {v for v in STATUS.values() if v not in status_opts}
    if missing:
        raise RuntimeError(f"project Status field lacks options {missing}; has {list(status_opts)}")
    items = gh("project", "item-list", str(pnum), "--owner", OWNER, "--format", "json", "--limit", "1000", json_out=True).get("items", [])
    item_by_number = {i["content"]["number"]: i["id"] for i in items if i.get("content", {}).get("number")}

    def set_field(item, field, option):
        gh("project", "item-edit", "--id", item, "--project-id", pid, "--field-id", fields[field]["id"],
           "--single-select-option-id", fields[field]["options"][option], write=True)

    for t in d.T:
        n = numbers[t["id"]]
        item = item_by_number.get(n)
        if not item:
            item = gh("project", "item-add", str(pnum), "--owner", OWNER,
                      "--url", f"https://github.com/{REPO}/issues/{n}", "--format", "json", json_out=True, write=True)["id"]
        eid = epic_of(t)
        set_field(item, "Status", STATUS[t["status"]])
        set_field(item, "Agent", t["agent"])
        set_field(item, "Phase", f"{t['phase']}. {d.PHASES[t['phase']]}")
        set_field(item, "Priority", t["prio"])
        set_field(item, "Epic", f"{eid[-2:]} {d.EPICS[eid][0]}")
        set_field(item, "MVP", "Yes" if t["id"] in d.MVP else "No")
    print(f"board: {len(d.T)} task items synced in project #{pnum}")
    print(f"open it: https://github.com/users/{OWNER}/projects/{pnum}")


# ------------------------------------------------------------------ main
def main():
    global DRY
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry-run", action="store_true", help="read GitHub, print the writes, change nothing")
    ap.add_argument("--skip-board", action="store_true", help="issues and labels only")
    ap.add_argument("--board-only", action="store_true", help="only the project board (issues must exist)")
    args = ap.parse_args()
    DRY = args.dry_run

    found = existing_issues()
    print(f"existing CF issues on GitHub: {len(found)}; backlog: {len(d.EPICS)} epics, {len(d.T)} tasks, {len(d.MVP)} MVP")
    numbers = {k: v["number"] for k, v in found.items()}

    if not args.board_only:
        ensure_labels()
        before = set(numbers)
        # pass 1: create/update epics and tasks (links to issues created later in this run stay IDs)
        for eid, (name, _desc, phases) in d.EPICS.items():
            done = all(t["status"] == "Done" for t in d.T if epic_of(t) == eid)
            upsert_issue(eid, name, epic_body(eid, numbers), ["type:epic", *[f"phase:{p}" for p in phases]], done, found, numbers)
        for t in d.T:
            upsert_issue(t["id"], t["title"], task_body(t, numbers), labels_for_task(t), t["status"] == "Done", found, numbers)
        # pass 2: only needed when issues were created in pass 1
        if not DRY and set(numbers) != before:
            for eid in d.EPICS:
                gh("issue", "edit", str(numbers[eid]), "--repo", REPO, "--body", epic_body(eid, numbers), write=True)
            for t in d.T:
                gh("issue", "edit", str(numbers[t["id"]]), "--repo", REPO, "--body", task_body(t, numbers), write=True)
        if not DRY:
            link_sub_issues(numbers)
    missing = [k for k in [*d.EPICS, *(t["id"] for t in d.T)] if k not in numbers]
    if missing:
        sys.exit(f"issues missing on GitHub: {missing[:5]}... run without --board-only first")
    if not args.skip_board:
        sync_board(numbers)
    print("done")


if __name__ == "__main__":
    main()
