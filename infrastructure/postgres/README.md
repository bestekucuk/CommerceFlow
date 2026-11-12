# infrastructure/postgres

Status: **empty scaffold**.

Will contain: Init scripts that create one database and one user per service (`product_db` … `notification_db`), `wal_level=logical`, publication and replication-slot setup for Debezium.

No secrets are committed; required variables are documented in `.env.example`.
