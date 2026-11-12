package kafka

import (
	"context"
	"errors"
	"testing"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/testsupport"
)

func TestDecodeProductCreated_FromContractSchema(t *testing.T) {
	schema, err := testsupport.ProductCreatedSchema()
	if err != nil {
		t.Fatal(err)
	}
	payload, err := testsupport.Encode(schema, 7, testsupport.ValidEvent("0190d1c4-6b8c-7c3e-9f5e-1a2b3c4d5e6f",
		"0190d1c4-6b8c-7c3e-9f5e-000000000001", "SHOE-42", "SHOE-43"))
	if err != nil {
		t.Fatal(err)
	}
	dec := NewDecoder(testsupport.StaticRegistry{7: schema})

	ev, err := dec.DecodeProductCreated(context.Background(), payload)
	if err != nil {
		t.Fatalf("decode: %v", err)
	}
	if ev.EventID != "0190d1c4-6b8c-7c3e-9f5e-1a2b3c4d5e6f" || ev.SchemaVersion != 1 || ev.CorrelationID == "" ||
		ev.ProductID != ev.AggregateID || len(ev.SKUs) != 2 || ev.SKUs[1].SKU != "SHOE-43" || ev.OccurredAt.IsZero() {
		t.Fatalf("unexpected event: %+v", ev)
	}
}

func TestDecodeProductCreated_PermanentFailures(t *testing.T) {
	schema, _ := testsupport.ProductCreatedSchema()
	good, _ := testsupport.Encode(schema, 7, testsupport.ValidEvent("e", "p", "SHOE-42"))
	dec := NewDecoder(testsupport.StaticRegistry{7: schema})
	tests := map[string][]byte{
		"not framed":       []byte("{\"json\":true}"),
		"unknown schema":   append([]byte{0, 0, 0, 0, 99}, good[5:]...),
		"truncated body":   good[:12],
		"too short header": {0, 1},
	}
	for name, value := range tests {
		t.Run(name, func(t *testing.T) {
			if _, err := dec.DecodeProductCreated(context.Background(), value); !errors.Is(err, ErrUndecodable) {
				t.Fatalf("err = %v, want ErrUndecodable", err)
			}
		})
	}
}
