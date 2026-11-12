-- Transactional outbox (docs/event-catalog/outbox-design.md). Debezium reads this table.
CREATE TABLE outbox (
    id             uuid        PRIMARY KEY,
    aggregate_type text        NOT NULL,
    aggregate_id   text        NOT NULL,
    type           text        NOT NULL,
    topic          text        NOT NULL,
    payload        bytea       NOT NULL,
    occurred_at    timestamptz NOT NULL DEFAULT now(),
    trace_parent   text
);
CREATE INDEX outbox_occurred_at_idx ON outbox (occurred_at);
