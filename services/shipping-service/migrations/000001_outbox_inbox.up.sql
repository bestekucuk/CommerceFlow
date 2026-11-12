SET lock_timeout = '3s';
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

-- Inbox for idempotent consumers (idempotent-consumer skill).
CREATE TABLE inbox (
    message_id  uuid        NOT NULL,
    consumer    text        NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, consumer)
);
CREATE INDEX inbox_received_at_idx ON inbox (received_at);
