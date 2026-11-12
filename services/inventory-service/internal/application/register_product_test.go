package application

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/domain"
)

func validEvent() ProductCreated {
	return ProductCreated{EventID: "0190d1c4-6b8c-7c3e-9f5e-000000000001", EventType: "ProductCreated",
		AggregateID: "0190d1c4-6b8c-7c3e-9f5e-0000000000aa", SchemaVersion: 1,
		CorrelationID: "c-1", ProductID: "0190d1c4-6b8c-7c3e-9f5e-0000000000aa", Name: "Shoe", Status: "DRAFT",
		SKUs: []ProductSKU{{SKU: "SHOE-42", Name: "42"}, {SKU: "SHOE-43", Name: "43"}}}
}

func TestValidate(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(*ProductCreated)
		ok     bool
	}{
		{"valid", func(*ProductCreated) {}, true},
		{"wrong type", func(e *ProductCreated) { e.EventType = "ProductUpdated" }, false},
		{"unsupported version", func(e *ProductCreated) { e.SchemaVersion = 2 }, false},
		{"missing id", func(e *ProductCreated) { e.EventID = "" }, false},
		{"event id not a uuid", func(e *ProductCreated) { e.EventID = "e-1" }, false},
		{"product id not a uuid", func(e *ProductCreated) { e.ProductID, e.AggregateID = "p-1", "p-1" }, false},
		{"aggregate mismatch", func(e *ProductCreated) { e.AggregateID = "other" }, false},
		{"missing name", func(e *ProductCreated) { e.Name = "" }, false},
		{"no skus", func(e *ProductCreated) { e.SKUs = nil }, false},
		{"bad sku", func(e *ProductCreated) { e.SKUs[0].SKU = "bad sku" }, false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			e := validEvent()
			tt.mutate(&e)
			items, err := Validate(e)
			if tt.ok {
				if err != nil || len(items) != 2 || items[0].OnHand != 0 || items[0].ProductID != "0190d1c4-6b8c-7c3e-9f5e-0000000000aa" {
					t.Fatalf("Validate() = %v, %v", items, err)
				}
				return
			}
			if !errors.Is(err, ErrInvalidEvent) {
				t.Fatalf("err = %v, want ErrInvalidEvent", err)
			}
		})
	}
}

type fakeTx struct {
	inbox    map[string]bool
	products int
	items    []domain.StockItem
	failWith error
}

func (f *fakeTx) RecordInbox(_ context.Context, id, consumer string) (bool, error) {
	if f.failWith != nil {
		return false, f.failWith
	}
	key := consumer + "/" + id
	if f.inbox[key] {
		return true, nil
	}
	f.inbox[key] = true
	return false, nil
}
func (f *fakeTx) UpsertProduct(context.Context, string, string, string, time.Time) error {
	f.products++
	return nil
}
func (f *fakeTx) CreateStockItems(_ context.Context, items []domain.StockItem) error {
	f.items = append(f.items, items...)
	return nil
}

type fakeStore struct{ tx *fakeTx }

func (s fakeStore) InTx(_ context.Context, fn func(Tx) error) error { return fn(s.tx) }

func TestHandle_ProcessesOnceAndSkipsDuplicates(t *testing.T) {
	tx := &fakeTx{inbox: map[string]bool{}}
	uc := NewRegisterProduct(fakeStore{tx})

	first, err := uc.Handle(context.Background(), validEvent())
	if err != nil || first != OutcomeProcessed {
		t.Fatalf("first = %v, %v", first, err)
	}
	second, err := uc.Handle(context.Background(), validEvent())
	if err != nil || second != OutcomeDuplicate {
		t.Fatalf("second = %v, %v", second, err)
	}
	if tx.products != 1 || len(tx.items) != 2 {
		t.Fatalf("effects applied twice: products=%d items=%d", tx.products, len(tx.items))
	}
}

func TestHandle_InvalidEventTouchesNothing(t *testing.T) {
	tx := &fakeTx{inbox: map[string]bool{}}
	e := validEvent()
	e.SKUs = nil
	if _, err := NewRegisterProduct(fakeStore{tx}).Handle(context.Background(), e); !errors.Is(err, ErrInvalidEvent) {
		t.Fatalf("err = %v", err)
	}
	if len(tx.inbox) != 0 || tx.products != 0 {
		t.Fatal("invalid event must not be recorded")
	}
}

func TestHandle_StoreErrorIsTransient(t *testing.T) {
	boom := errors.New("connection refused")
	_, err := NewRegisterProduct(fakeStore{&fakeTx{inbox: map[string]bool{}, failWith: boom}}).Handle(context.Background(), validEvent())
	if !errors.Is(err, boom) || errors.Is(err, ErrInvalidEvent) {
		t.Fatalf("err = %v, want transient store error", err)
	}
}
