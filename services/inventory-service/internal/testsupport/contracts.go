// Package testsupport builds ProductCreated test messages from the real contract files in
// contracts/events (never from a copy). Used only by tests.
package testsupport

import (
	"context"
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/hamba/avro/v2"
	"github.com/twmb/franz-go/pkg/sr"
)

// RepoRoot returns the repository root (four levels above this package).
func RepoRoot() string {
	_, file, _, _ := runtime.Caller(0)
	return filepath.Clean(filepath.Join(filepath.Dir(file), "..", "..", "..", ".."))
}

// ProductCreatedSchema returns ProductCreated.v1 with EventMetadata inlined, the form the
// registry holds (infrastructure/scripts/register-schemas.ps1 does the same).
func ProductCreatedSchema() (string, error) {
	root := RepoRoot()
	meta, err := os.ReadFile(filepath.Join(root, "contracts", "events", "common", "EventMetadata.v1.avsc"))
	if err != nil {
		return "", err
	}
	pc, err := os.ReadFile(filepath.Join(root, "contracts", "events", "product", "ProductCreated.v1.avsc"))
	if err != nil {
		return "", err
	}
	ref := `"com.commerceflow.events.common.EventMetadata"`
	if !strings.Contains(string(pc), ref) {
		return "", fmt.Errorf("ProductCreated no longer references EventMetadata")
	}
	return strings.Replace(string(pc), ref, string(meta), 1), nil
}

// Event is a test ProductCreated in plain Go form.
type Event struct {
	EventID, EventType, AggregateID, CorrelationID, ProductID, Name string
	SchemaVersion                                                   int
	SKUs                                                            []string
}

// ValidEvent returns a valid event for one product.
func ValidEvent(eventID, productID string, skus ...string) Event {
	return Event{EventID: eventID, EventType: "ProductCreated", AggregateID: productID, CorrelationID: "corr-" + eventID,
		ProductID: productID, Name: "Trail Shoe", SchemaVersion: 1, SKUs: skus}
}

// Encode returns the Confluent-framed Avro bytes of e for the given schema id.
func Encode(schemaJSON string, schemaID int, e Event) ([]byte, error) {
	schema, err := avro.Parse(schemaJSON)
	if err != nil {
		return nil, err
	}
	skus := make([]map[string]any, 0, len(e.SKUs))
	for _, s := range e.SKUs {
		skus = append(skus, map[string]any{"sku": s, "name": "Variant " + s})
	}
	rec := map[string]any{
		"metadata": map[string]any{
			"eventId": e.EventID, "eventType": e.EventType, "aggregateType": "product", "aggregateId": e.AggregateID,
			"occurredAt": time.Date(2026, 11, 12, 10, 0, 0, 0, time.UTC), "schemaVersion": e.SchemaVersion,
			"correlationId": e.CorrelationID, "causationId": nil, "producer": "product-service",
		},
		"payload": map[string]any{
			"productId": e.ProductID, "name": e.Name, "categoryId": nil, "status": "DRAFT", "skus": skus,
		},
	}
	body, err := avro.Marshal(schema, rec)
	if err != nil {
		return nil, err
	}
	frame := make([]byte, 5, 5+len(body))
	binary.BigEndian.PutUint32(frame[1:], uint32(schemaID))
	return append(frame, body...), nil
}

// StaticRegistry serves fixed schemas by id (stands in for Schema Registry in tests).
type StaticRegistry map[int]string

func (r StaticRegistry) SchemaByID(_ context.Context, id int) (sr.Schema, error) {
	s, ok := r[id]
	if !ok {
		return sr.Schema{}, &sr.ResponseError{StatusCode: 404, Message: "schema not found"}
	}
	return sr.Schema{Schema: s, Type: sr.TypeAvro}, nil
}
