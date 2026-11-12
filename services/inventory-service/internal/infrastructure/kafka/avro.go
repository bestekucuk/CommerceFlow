// Package kafka contains the Kafka adapters: Avro decoding and the ProductCreated consumer.
package kafka

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/hamba/avro/v2"
	"github.com/twmb/franz-go/pkg/sr"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/application"
)

// ErrUndecodable marks payloads that can never be decoded (permanent -> DLT).
var ErrUndecodable = errors.New("undecodable payload")

// productCreatedRecord mirrors contracts/events/product/ProductCreated.v1.avsc. Decoding
// uses the WRITER schema from the registry, so added optional fields are ignored safely.
type productCreatedRecord struct {
	Metadata struct {
		EventID       string    `avro:"eventId"`
		EventType     string    `avro:"eventType"`
		AggregateType string    `avro:"aggregateType"`
		AggregateID   string    `avro:"aggregateId"`
		OccurredAt    time.Time `avro:"occurredAt"`
		SchemaVersion int       `avro:"schemaVersion"`
		CorrelationID string    `avro:"correlationId"`
		CausationID   *string   `avro:"causationId"`
		Producer      string    `avro:"producer"`
	} `avro:"metadata"`
	Payload struct {
		ProductID  string  `avro:"productId"`
		Name       string  `avro:"name"`
		CategoryID *string `avro:"categoryId"`
		Status     string  `avro:"status"`
		SKUs       []struct {
			SKU  string `avro:"sku"`
			Name string `avro:"name"`
		} `avro:"skus"`
	} `avro:"payload"`
}

// SchemaSource returns the schema text for a registry id.
type SchemaSource interface {
	SchemaByID(ctx context.Context, id int) (sr.Schema, error)
}

// Decoder decodes Confluent-framed Avro (magic byte 0, 4-byte schema id, body).
type Decoder struct {
	registry SchemaSource
	mu       sync.Mutex
	cache    map[int]avro.Schema
}

// NewDecoder returns a decoder that caches parsed writer schemas.
func NewDecoder(registry SchemaSource) *Decoder {
	return &Decoder{registry: registry, cache: map[int]avro.Schema{}}
}

func (d *Decoder) schema(ctx context.Context, id int) (avro.Schema, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if s, ok := d.cache[id]; ok {
		return s, nil
	}
	raw, err := d.registry.SchemaByID(ctx, id)
	if err != nil {
		var re *sr.ResponseError
		if errors.As(err, &re) && re.StatusCode == 404 {
			return nil, fmt.Errorf("%w: schema id %d not in registry", ErrUndecodable, id)
		}
		return nil, fmt.Errorf("fetch schema %d: %w", id, err) // transient
	}
	parsed, err := avro.Parse(raw.Schema)
	if err != nil {
		return nil, fmt.Errorf("%w: parse schema %d: %v", ErrUndecodable, id, err)
	}
	d.cache[id] = parsed
	return parsed, nil
}

// DecodeProductCreated decodes a record value into the application event.
func (d *Decoder) DecodeProductCreated(ctx context.Context, value []byte) (application.ProductCreated, error) {
	if len(value) < 5 || value[0] != 0 {
		return application.ProductCreated{}, fmt.Errorf("%w: not Confluent Avro framing", ErrUndecodable)
	}
	id := int(binary.BigEndian.Uint32(value[1:5]))
	schema, err := d.schema(ctx, id)
	if err != nil {
		return application.ProductCreated{}, err
	}
	var rec productCreatedRecord
	if err := avro.Unmarshal(schema, value[5:], &rec); err != nil {
		return application.ProductCreated{}, fmt.Errorf("%w: %v", ErrUndecodable, err)
	}
	ev := application.ProductCreated{
		EventID:       rec.Metadata.EventID,
		EventType:     rec.Metadata.EventType,
		AggregateID:   rec.Metadata.AggregateID,
		SchemaVersion: rec.Metadata.SchemaVersion,
		CorrelationID: rec.Metadata.CorrelationID,
		OccurredAt:    rec.Metadata.OccurredAt,
		ProductID:     rec.Payload.ProductID,
		Name:          rec.Payload.Name,
		Status:        rec.Payload.Status,
	}
	for _, s := range rec.Payload.SKUs {
		ev.SKUs = append(ev.SKUs, application.ProductSKU{SKU: s.SKU, Name: s.Name})
	}
	return ev, nil
}
