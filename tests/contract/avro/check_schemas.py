"""Static checks for contracts/events/**/*.avsc (no Schema Registry needed).

- every schema parses with the Avro library, resolving shared types from common/
- namespace starts with com.commerceflow.events
- file name is <RecordName>.v<N>.avsc and matches the record name
- every enum has a default (forward-compatible readers; convention: UNKNOWN)

Compatibility against registered versions needs a registry: locally
infrastructure/scripts/register-schemas.ps1 -CheckOnly; in CI CF-040.

Usage: python tests/contract/avro/check_schemas.py [contracts/events]
"""
import json
import re
import sys
from pathlib import Path

import avro.schema

root = Path(sys.argv[1] if len(sys.argv) > 1 else "contracts/events")
files = sorted(root.rglob("*.avsc"), key=lambda p: (p.parent.name != "common", str(p)))
if not files:
    sys.exit(f"no .avsc files under {root}")

names = avro.schema.Names()
errors = []


def enums(node):
    if isinstance(node, dict):
        if node.get("type") == "enum":
            yield node
        for v in node.values():
            yield from enums(v)
    elif isinstance(node, list):
        for v in node:
            yield from enums(v)


for f in files:
    rel = f.as_posix()
    try:
        raw = json.loads(f.read_text(encoding="utf-8"))
        avro.schema.make_avsc_object(raw, names)
    except Exception as e:  # noqa: BLE001 - report every failure, keep going
        errors.append(f"{rel}: does not parse: {e}")
        continue
    ns = raw.get("namespace", "")
    if not ns.startswith("com.commerceflow.events"):
        errors.append(f"{rel}: namespace '{ns}' must start with com.commerceflow.events")
    m = re.fullmatch(r"([A-Z][A-Za-z0-9]*)\.v(\d+)\.avsc", f.name)
    if not m:
        errors.append(f"{rel}: file name must be <RecordName>.v<N>.avsc")
    elif m.group(1) != raw.get("name"):
        errors.append(f"{rel}: record name '{raw.get('name')}' does not match file name")
    for e in enums(raw):
        if "default" not in e:
            errors.append(f"{rel}: enum {e.get('name')} has no default")
    print(f"ok   {rel}")

for e in errors:
    print(f"FAIL {e}")
print(f"{len(files)} schema(s), {len(errors)} error(s)")
sys.exit(1 if errors else 0)
