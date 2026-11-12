SET lock_timeout = '3s';
-- Inbox for idempotent consumers (idempotent-consumer skill).
CREATE TABLE inbox (
    message_id  uuid        NOT NULL,
    consumer    text        NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (message_id, consumer)
);
CREATE INDEX inbox_received_at_idx ON inbox (received_at);
