# infrastructure/redis

Status: **implemented for local development** — see `infrastructure/README.md`.

| File | Purpose |
|---|---|
| `start-redis.sh` | Builds the ACL file from environment variables and starts Redis (default user off, one user per owning service with key-prefix restriction, read-only monitoring user) |
