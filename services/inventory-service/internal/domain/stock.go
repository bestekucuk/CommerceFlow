// Package domain holds the inventory bounded context's entities and rules. Standard library only.
package domain

import (
	"errors"
	"fmt"
	"regexp"
)

// ErrInvalid marks input that violates an inventory invariant; it is never retryable.
var ErrInvalid = errors.New("invalid inventory data")

// ErrNotFound is returned when a stock item does not exist.
var ErrNotFound = errors.New("not found")

var skuPattern = regexp.MustCompile(`^[A-Z0-9][A-Z0-9-]{2,39}$`)

// SKU is a stock-keeping unit code (same format the catalog enforces).
type SKU string

// ParseSKU validates a SKU code.
func ParseSKU(s string) (SKU, error) {
	if !skuPattern.MatchString(s) {
		return "", fmt.Errorf("%w: SKU %q must match %s", ErrInvalid, s, skuPattern)
	}
	return SKU(s), nil
}

// StockItem is the stock of one SKU. A new item starts with nothing on hand or reserved.
type StockItem struct {
	SKU       SKU
	ProductID string
	OnHand    int
	Reserved  int
}

// NewStockItem creates an empty stock item for a SKU of a catalog product.
func NewStockItem(sku SKU, productID string) (StockItem, error) {
	if productID == "" {
		return StockItem{}, fmt.Errorf("%w: product id is required", ErrInvalid)
	}
	return StockItem{SKU: sku, ProductID: productID}, nil
}

// Available is the quantity that can still be reserved.
func (s StockItem) Available() int { return s.OnHand - s.Reserved }
