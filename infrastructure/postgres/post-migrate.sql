-- Runs as <svc>_migrator after the service's own migrations created the outbox table
-- (infrastructure/scripts/migrate.ps1). Idempotent.
-- psql variables: cdc (CDC role), pub (publication name).
--
-- Grants the CDC role read access to the outbox only, and creates a publication limited
-- to the outbox, so Debezium never sees business tables.

SELECT to_regclass('public.outbox') IS NOT NULL AS has_outbox \gset
\if :has_outbox
GRANT SELECT ON public.outbox TO :"cdc";
SELECT NOT EXISTS (SELECT 1 FROM pg_publication WHERE pubname = :'pub') AS need_pub \gset
\if :need_pub
CREATE PUBLICATION :"pub" FOR TABLE public.outbox;
\endif
SELECT format('publication %s on public.outbox ready', :'pub') AS result;
\else
SELECT 'no outbox table yet - run the service migrations first' AS result;
\endif
