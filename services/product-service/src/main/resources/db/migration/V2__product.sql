-- Catalog: products and their SKUs (owned by product-service only).
SET lock_timeout = '3s';

CREATE TABLE product (
    id          uuid        PRIMARY KEY,
    name        text        NOT NULL CONSTRAINT product_name_chk CHECK (length(name) BETWEEN 1 AND 200),
    description text        CONSTRAINT product_description_chk CHECK (description IS NULL OR length(description) <= 4000),
    category_id uuid,
    status      text        NOT NULL CONSTRAINT product_status_chk CHECK (status IN ('DRAFT', 'ACTIVE')),
    created_at  timestamptz NOT NULL,
    version     bigint      NOT NULL DEFAULT 0
);

CREATE TABLE product_sku (
    sku        text    PRIMARY KEY CONSTRAINT product_sku_code_chk CHECK (sku ~ '^[A-Z0-9][A-Z0-9-]{2,39}$'),
    product_id uuid    NOT NULL REFERENCES product (id) ON DELETE CASCADE,
    position   int     NOT NULL,
    name       text    NOT NULL CONSTRAINT product_sku_name_chk CHECK (length(name) BETWEEN 1 AND 200),
    CONSTRAINT product_sku_product_position_key UNIQUE (product_id, position)
);
