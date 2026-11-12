package postgres

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/application"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/domain"
)

// Store implements application.Store with pgx transactions.
type Store struct {
	pool *pgxpool.Pool
}

// NewStore returns a store backed by the pool.
func NewStore(pool *pgxpool.Pool) *Store { return &Store{pool: pool} }

// InTx runs fn in one READ COMMITTED transaction. Data errors that will fail the same way
// on every retry (SQLSTATE classes 22 data exception and 23 integrity violation) are
// reported as permanent (application.ErrInvalidEvent) so the message is dead-lettered.
func (s *Store) InTx(ctx context.Context, fn func(application.Tx) error) error {
	err := pgx.BeginFunc(ctx, s.pool, func(tx pgx.Tx) error { return fn(&pgTx{tx: tx}) })
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && (strings.HasPrefix(pgErr.Code, "22") || strings.HasPrefix(pgErr.Code, "23")) {
		return fmt.Errorf("%w: %v", application.ErrInvalidEvent, err)
	}
	return err
}

type pgTx struct{ tx pgx.Tx }

func (t *pgTx) RecordInbox(ctx context.Context, messageID, consumer string) (bool, error) {
	tag, err := t.tx.Exec(ctx,
		`INSERT INTO inbox (message_id, consumer) VALUES ($1, $2) ON CONFLICT DO NOTHING`, messageID, consumer)
	if err != nil {
		return false, fmt.Errorf("inbox insert: %w", err)
	}
	return tag.RowsAffected() == 0, nil
}

func (t *pgTx) UpsertProduct(ctx context.Context, productID, name, status string, occurredAt time.Time) error {
	_, err := t.tx.Exec(ctx, `
		INSERT INTO product_projection (product_id, name, status, occurred_at)
		VALUES ($1, $2, $3, $4)
		ON CONFLICT (product_id) DO NOTHING`, productID, name, status, occurredAt)
	if err != nil {
		return fmt.Errorf("upsert product projection: %w", err)
	}
	return nil
}

func (t *pgTx) CreateStockItems(ctx context.Context, items []domain.StockItem) error {
	for _, it := range items {
		tag, err := t.tx.Exec(ctx, `
			INSERT INTO stock_item (sku, product_id, on_hand, reserved)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (sku) DO NOTHING`, string(it.SKU), it.ProductID, it.OnHand, it.Reserved)
		if err != nil {
			return fmt.Errorf("insert stock item %s: %w", it.SKU, err)
		}
		if tag.RowsAffected() == 1 {
			continue
		}
		// the SKU exists: fine if it belongs to this product, catalog drift otherwise
		var owner string
		if err := t.tx.QueryRow(ctx, `SELECT product_id::text FROM stock_item WHERE sku = $1`, string(it.SKU)).Scan(&owner); err != nil {
			return fmt.Errorf("read stock item %s: %w", it.SKU, err)
		}
		if owner != it.ProductID {
			return fmt.Errorf("%w: SKU %s already belongs to product %s", application.ErrInvalidEvent, it.SKU, owner)
		}
	}
	return nil
}

// StockBySKU reads one stock item (used by the read API).
func (s *Store) StockBySKU(ctx context.Context, sku string) (domain.StockItem, error) {
	var it domain.StockItem
	var code string
	err := s.pool.QueryRow(ctx,
		`SELECT sku, product_id::text, on_hand, reserved FROM stock_item WHERE sku = $1`, sku).
		Scan(&code, &it.ProductID, &it.OnHand, &it.Reserved)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.StockItem{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.StockItem{}, fmt.Errorf("read stock %s: %w", sku, err)
	}
	it.SKU = domain.SKU(code)
	return it, nil
}
