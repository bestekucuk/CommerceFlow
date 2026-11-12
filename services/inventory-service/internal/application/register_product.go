// Package application holds inventory use cases and the ports they need. It depends on
// domain only.
package application

import (
	"context"
	"errors"
	"fmt"
	"regexp"
	"time"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/domain"
)

// ErrInvalidEvent marks a message that can never be processed (it goes to the DLT).
var ErrInvalidEvent = errors.New("invalid event")

// ProductCreated is the application-level view of the ProductCreated v1 contract. The
// Kafka adapter maps the Avro record into it; the use case never sees Avro.
type ProductCreated struct {
	EventID       string
	EventType     string
	AggregateID   string
	SchemaVersion int
	CorrelationID string
	OccurredAt    time.Time
	ProductID     string
	Name          string
	Status        string
	SKUs          []ProductSKU
}

// ProductSKU is one SKU of a created product.
type ProductSKU struct {
	SKU  string
	Name string
}

// Outcome reports what processing did.
type Outcome string

const (
	OutcomeProcessed Outcome = "processed"
	OutcomeDuplicate Outcome = "duplicate"
)

// Tx is the unit of work offered by the store. Every call joins one database transaction.
type Tx interface {
	// RecordInbox stores the message id for this consumer; duplicate=true if it was already there.
	RecordInbox(ctx context.Context, messageID, consumer string) (duplicate bool, err error)
	UpsertProduct(ctx context.Context, productID, name, status string, occurredAt time.Time) error
	// CreateStockItems inserts items that do not exist yet; existing SKUs are left untouched.
	CreateStockItems(ctx context.Context, items []domain.StockItem) error
}

// Store runs fn in one transaction: committed if fn returns nil, rolled back otherwise.
type Store interface {
	InTx(ctx context.Context, fn func(Tx) error) error
}

var uuidPattern = regexp.MustCompile(`^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$`)

// ConsumerName identifies this handler in the inbox table.
const ConsumerName = "inventory-service.product-created"

// RegisterProduct creates an empty stock item for every SKU of a newly created product.
// Inbox record, product projection and stock items are written in ONE transaction, so a
// redelivered event is detected and has no second effect.
type RegisterProduct struct {
	store Store
}

// NewRegisterProduct returns the use case.
func NewRegisterProduct(store Store) *RegisterProduct { return &RegisterProduct{store: store} }

// Validate checks the event against the contract and inventory rules.
func Validate(e ProductCreated) ([]domain.StockItem, error) {
	switch {
	case e.EventType != "ProductCreated":
		return nil, fmt.Errorf("%w: unexpected event type %q", ErrInvalidEvent, e.EventType)
	case e.SchemaVersion != 1:
		return nil, fmt.Errorf("%w: unsupported schema version %d", ErrInvalidEvent, e.SchemaVersion)
	case !uuidPattern.MatchString(e.EventID):
		// the Avro uuid logical type is not enforced on the wire
		return nil, fmt.Errorf("%w: event id %q is not a UUID", ErrInvalidEvent, e.EventID)
	case !uuidPattern.MatchString(e.ProductID):
		return nil, fmt.Errorf("%w: product id %q is not a UUID", ErrInvalidEvent, e.ProductID)
	case e.ProductID == "" || e.AggregateID != e.ProductID:
		return nil, fmt.Errorf("%w: aggregate id %q does not match product id %q", ErrInvalidEvent, e.AggregateID, e.ProductID)
	case e.Name == "":
		return nil, fmt.Errorf("%w: missing product name", ErrInvalidEvent)
	case len(e.SKUs) == 0:
		return nil, fmt.Errorf("%w: product has no SKUs", ErrInvalidEvent)
	}
	items := make([]domain.StockItem, 0, len(e.SKUs))
	for _, s := range e.SKUs {
		sku, err := domain.ParseSKU(s.SKU)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalidEvent, err)
		}
		item, err := domain.NewStockItem(sku, e.ProductID)
		if err != nil {
			return nil, fmt.Errorf("%w: %v", ErrInvalidEvent, err)
		}
		items = append(items, item)
	}
	return items, nil
}

// Handle processes one ProductCreated event. Errors wrapping ErrInvalidEvent are permanent;
// any other error is transient and the caller retries.
func (u *RegisterProduct) Handle(ctx context.Context, e ProductCreated) (Outcome, error) {
	items, err := Validate(e)
	if err != nil {
		return "", err
	}
	outcome := OutcomeProcessed
	err = u.store.InTx(ctx, func(tx Tx) error {
		dup, err := tx.RecordInbox(ctx, e.EventID, ConsumerName)
		if err != nil {
			return err
		}
		if dup {
			outcome = OutcomeDuplicate
			return nil
		}
		if err := tx.UpsertProduct(ctx, e.ProductID, e.Name, e.Status, e.OccurredAt); err != nil {
			return err
		}
		return tx.CreateStockItems(ctx, items)
	})
	if err != nil {
		return "", err
	}
	return outcome, nil
}
