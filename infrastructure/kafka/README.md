# infrastructure/kafka

Status: **implemented for local development** — see `infrastructure/README.md`.

| File | Purpose |
|---|---|
| `topics.csv` | Declared topics: name, partitions, retention, kind (events, commands, dlt, local-check) |
| `consumer-groups.csv` | Expected consumer groups (= service names) and their topics |
| `create-topics.sh` | Idempotent topic creation/retention update, run by the `kafka-init` container |

Single broker, replication factor 1, auto topic creation disabled.
