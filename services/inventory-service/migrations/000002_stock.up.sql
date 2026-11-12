SET lock_timeout = '3s';

-- Products known to inventory (projection of catalog events; owned by inventory-service).
CREATE TABLE product_projection (
    product_id  uuid        PRIMARY KEY,
    name        text        NOT NULL,
    status      text        NOT NULL,
    occurred_at timestamptz NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE stock_item (
    sku        text        PRIMARY KEY CONSTRAINT stock_item_sku_chk CHECK (sku ~ '^[A-Z0-9][A-Z0-9-]{2,39}$'),
    product_id uuid        NOT NULL REFERENCES product_projection (product_id),
    on_hand    int         NOT NULL DEFAULT 0 CONSTRAINT stock_item_on_hand_chk CHECK (on_hand >= 0),
    reserved   int         NOT NULL DEFAULT 0 CONSTRAINT stock_item_reserved_chk CHECK (reserved >= 0 AND reserved <= on_hand),
    version    bigint      NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX stock_item_product_idx ON stock_item (product_id);
