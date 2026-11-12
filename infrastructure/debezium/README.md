# infrastructure/debezium

Status: **implemented for local development** — see `infrastructure/README.md`.

| File | Purpose |
|---|---|
| `connectors/<svc>-outbox.json` | Outbox connector per publishing service (7). Passwords as `${env:<SVC>_DB_CDC_PASSWORD}` |

Register with `infrastructure/scripts/register-connectors.ps1`. Design: `docs/event-catalog/debezium-design.md`.
