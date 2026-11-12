#!/usr/bin/env bash
# Runs once, on first start of an empty PostgreSQL volume (docker-entrypoint-initdb.d).
# Creates one database and separate roles per service (docs/architecture/database-ownership.md):
#   <svc>_migrator  owns the database, runs migrations (DDL)
#   <svc>_service   application runtime role (DML only, via default privileges)
#   <svc>_cdc       Debezium role (REPLICATION; SELECT on outbox is granted after migrations)
# plus a read-only `monitoring` role for postgres-exporter.
# Passwords come from environment variables (.env); none are written in this file.
# May be sourced by the entrypoint, so it avoids `set -u` and `exit`.
set -eo pipefail

SERVICES="product order inventory payment customer pricing shipping notification"
PUBLISHERS="product order inventory payment customer pricing shipping"

require() {
    local name="$1"
    if [ -z "${!name}" ]; then
        echo "commerceflow init: environment variable $name is not set (copy .env.example to .env)" >&2
        return 1
    fi
    printf '%s' "${!name}"
}

psql_super() {
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" "$@"
}

monitoring_pw="$(require MONITORING_DB_PASSWORD)"
psql_super --dbname postgres -v pw="$monitoring_pw" <<'SQL'
CREATE ROLE monitoring LOGIN PASSWORD :'pw';
GRANT pg_monitor TO monitoring;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
SQL

for svc in $SERVICES; do
    upper="$(echo "$svc" | tr '[:lower:]' '[:upper:]')"
    migrator_pw="$(require "${upper}_DB_MIGRATOR_PASSWORD")"
    service_pw="$(require "${upper}_DB_SERVICE_PASSWORD")"
    cdc_pw=""
    case " $PUBLISHERS " in *" $svc "*) cdc_pw="$(require "${upper}_DB_CDC_PASSWORD")" ;; esac

    echo "commerceflow init: creating ${svc}_db and roles"
    psql_super --dbname postgres \
        -v migrator="${svc}_migrator" -v service="${svc}_service" -v cdc="${svc}_cdc" -v db="${svc}_db" \
        -v migrator_pw="$migrator_pw" -v service_pw="$service_pw" -v cdc_pw="$cdc_pw" <<'SQL'
CREATE ROLE :"migrator" LOGIN PASSWORD :'migrator_pw';
CREATE ROLE :"service" LOGIN PASSWORD :'service_pw';
SELECT :'cdc_pw' <> '' AS has_cdc \gset
\if :has_cdc
CREATE ROLE :"cdc" LOGIN REPLICATION PASSWORD :'cdc_pw';
\endif
CREATE DATABASE :"db" OWNER :"migrator";
REVOKE ALL ON DATABASE :"db" FROM PUBLIC;
GRANT CONNECT ON DATABASE :"db" TO :"service", monitoring;
\if :has_cdc
GRANT CONNECT ON DATABASE :"db" TO :"cdc";
\endif
\connect :"db"
REVOKE ALL ON SCHEMA public FROM PUBLIC;
ALTER SCHEMA public OWNER TO :"migrator";
GRANT USAGE ON SCHEMA public TO :"service";
\if :has_cdc
GRANT USAGE ON SCHEMA public TO :"cdc";
\endif
ALTER DEFAULT PRIVILEGES FOR ROLE :"migrator" IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO :"service";
ALTER DEFAULT PRIVILEGES FOR ROLE :"migrator" IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO :"service";
SQL
done

echo "commerceflow init: done"
