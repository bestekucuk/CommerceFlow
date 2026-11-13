-- Current price per SKU. version drives optimistic concurrency (HTTP ETag / If-Match).
CREATE TABLE price (
    sku          text        PRIMARY KEY CHECK (sku ~ '^[A-Z0-9][A-Z0-9-]{2,39}$'),
    amount_minor bigint      NOT NULL CHECK (amount_minor BETWEEN 0 AND 10000000000000),
    currency     char(3)     NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    version      integer     NOT NULL CHECK (version >= 1),
    updated_at   timestamptz NOT NULL
);

-- A quote freezes the prices of a basket until expires_at. Rows are never updated.
CREATE TABLE quote (
    id           uuid        PRIMARY KEY,
    currency     char(3)     NOT NULL CHECK (currency ~ '^[A-Z]{3}$'),
    total_minor  bigint      NOT NULL CHECK (total_minor >= 0),
    created_at   timestamptz NOT NULL,
    expires_at   timestamptz NOT NULL,
    CHECK (expires_at > created_at)
);

CREATE TABLE quote_line (
    quote_id         uuid    NOT NULL REFERENCES quote (id) ON DELETE CASCADE,
    line_no          integer NOT NULL,
    sku              text    NOT NULL CHECK (sku ~ '^[A-Z0-9][A-Z0-9-]{2,39}$'),
    quantity         integer NOT NULL CHECK (quantity BETWEEN 1 AND 99),
    unit_price_minor bigint  NOT NULL CHECK (unit_price_minor >= 0),
    PRIMARY KEY (quote_id, line_no),
    UNIQUE (quote_id, sku)
);

-- Expired quotes are cleaned up by a retention job later (CF-094), keeping them well beyond
-- the order saga timeout; this index serves it.
CREATE INDEX quote_expires_at_idx ON quote (expires_at);
