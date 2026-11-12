# infrastructure/postgres

Status: **implemented for local development** — see `infrastructure/README.md`.

| File | Purpose |
|---|---|
| `init/10-service-databases.sh` | First-start init: 8 databases, migrator/service/cdc roles per service, `monitoring` role; passwords from `.env` |
| `post-migrate.sql` | After a service migration: CDC `SELECT` grant on `outbox` and publication `cf_<svc>_outbox` |

Server settings (`wal_level=logical`, slots, senders, `max_slot_wal_keep_size`) are command flags in `docker-compose.yml`.
