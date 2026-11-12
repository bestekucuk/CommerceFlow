//go:build e2e

// Package integration holds cross-service tests that run against the local Compose stack.
// Run with: powershell -File tests/integration/run-e2e.ps1
package integration

import (
	"bytes"
	"context"
	"crypto/rand"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/hamba/avro/v2"
	"github.com/twmb/franz-go/pkg/kgo"
	"github.com/twmb/franz-go/pkg/sr"
)

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

var (
	productURL   = env("E2E_PRODUCT_URL", "http://product-service:8081")
	inventoryURL = env("E2E_INVENTORY_URL", "http://inventory-service:8083")
	brokers      = strings.Split(env("E2E_KAFKA_BROKERS", "kafka:29092"), ",")
	registryURL  = env("E2E_SCHEMA_REGISTRY_URL", "http://schema-registry:8081")
	tempoURL     = env("E2E_TEMPO_URL", "http://tempo:3200")
)

func randomHex(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

type createdProduct struct {
	ID   string `json:"id"`
	Skus []struct {
		Sku string `json:"sku"`
	} `json:"skus"`
}

type productCreated struct {
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
		ProductID string `avro:"productId"`
		Name      string `avro:"name"`
		Status    string `avro:"status"`
		SKUs      []struct {
			SKU string `avro:"sku"`
		} `avro:"skus"`
	} `avro:"payload"`
}

// TestProductCreatedFlowsFromHTTPToInventory verifies, on the running stack:
// HTTP POST -> product-service (product + outbox in one tx) -> WAL -> Debezium Outbox Event
// Router -> cf.product.events.v1 -> inventory-service consumer (inbox) -> stock item, with
// one correlation id and one trace across all hops.
func TestProductCreatedFlowsFromHTTPToInventory(t *testing.T) {
	traceID := randomHex(16)
	traceparent := fmt.Sprintf("00-%s-%s-01", traceID, randomHex(8))
	correlationID := "e2e-" + randomHex(6)
	sku := "E2E-" + strings.ToUpper(randomHex(4))
	t.Logf("trace_id=%s correlation_id=%s sku=%s", traceID, correlationID, sku)

	// 1. HTTP request to product-service
	body := fmt.Sprintf(`{"name":"E2E Shoe","skus":[{"sku":%q,"name":"Size 42"}]}`, sku)
	req, _ := http.NewRequest(http.MethodPost, productURL+"/v1/products", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Correlation-Id", correlationID)
	req.Header.Set("traceparent", traceparent)
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("POST /v1/products: %v", err)
	}
	raw, _ := io.ReadAll(resp.Body)
	resp.Body.Close()
	if resp.StatusCode != http.StatusCreated {
		t.Fatalf("POST status %d: %s", resp.StatusCode, raw)
	}
	var product createdProduct
	if err := json.Unmarshal(raw, &product); err != nil {
		t.Fatal(err)
	}
	t.Logf("product created id=%s", product.ID)

	// 2. Debezium delivered the outbox row to Kafka
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()
	cl, err := kgo.NewClient(kgo.SeedBrokers(brokers...), kgo.ConsumeTopics("cf.product.events.v1"),
		kgo.ConsumeResetOffset(kgo.NewOffset().AtStart()))
	if err != nil {
		t.Fatal(err)
	}
	defer cl.Close()
	var rec *kgo.Record
	for rec == nil {
		fetches := cl.PollFetches(ctx)
		if ctx.Err() != nil {
			t.Fatal("ProductCreated did not arrive on cf.product.events.v1 within 60s (check connector product-outbox)")
		}
		fetches.EachRecord(func(r *kgo.Record) {
			if string(r.Key) == product.ID {
				rec = r
			}
		})
	}
	hdr := map[string]string{}
	for _, h := range rec.Headers {
		hdr[h.Key] = string(h.Value)
	}
	t.Logf("kafka record partition=%d offset=%d headers=%v", rec.Partition, rec.Offset, keys(hdr))
	if hdr["eventType"] != "ProductCreated" || hdr["aggregateType"] != "product" || hdr["id"] == "" {
		t.Fatalf("unexpected headers: %v", hdr)
	}
	if !strings.Contains(hdr["traceparent"], traceID) {
		t.Fatalf("traceparent header %q does not carry trace %s", hdr["traceparent"], traceID)
	}

	// 3. payload is Avro written with the registered schema
	if len(rec.Value) < 5 || rec.Value[0] != 0 {
		t.Fatalf("value is not Confluent-framed Avro")
	}
	schemaID := int(binary.BigEndian.Uint32(rec.Value[1:5]))
	reg, err := sr.NewClient(sr.URLs(registryURL))
	if err != nil {
		t.Fatal(err)
	}
	s, err := reg.SchemaByID(ctx, schemaID)
	if err != nil {
		t.Fatalf("schema %d: %v", schemaID, err)
	}
	parsed, err := avro.Parse(s.Schema)
	if err != nil {
		t.Fatal(err)
	}
	var ev productCreated
	if err := avro.Unmarshal(parsed, rec.Value[5:], &ev); err != nil {
		t.Fatalf("decode: %v", err)
	}
	m := ev.Metadata
	switch {
	case m.EventID != hdr["id"]:
		t.Fatalf("metadata.eventId %s != header id %s", m.EventID, hdr["id"])
	case m.EventType != "ProductCreated" || m.AggregateType != "product" || m.AggregateID != product.ID:
		t.Fatalf("unexpected envelope: %+v", m)
	case m.SchemaVersion != 1 || m.Producer != "product-service" || m.CausationID != nil:
		t.Fatalf("unexpected envelope: %+v", m)
	case m.CorrelationID != correlationID:
		t.Fatalf("correlationId %q, want %q", m.CorrelationID, correlationID)
	case ev.Payload.ProductID != product.ID || len(ev.Payload.SKUs) != 1 || ev.Payload.SKUs[0].SKU != sku:
		t.Fatalf("unexpected payload: %+v", ev.Payload)
	}
	t.Logf("event ok: eventId=%s schemaId=%d", m.EventID, schemaID)

	// 4. inventory-service consumed it
	var stock map[string]any
	waitFor(t, 60*time.Second, "stock item in inventory-service", func() bool {
		r, err := http.Get(inventoryURL + "/v1/stock/" + sku)
		if err != nil {
			return false
		}
		defer r.Body.Close()
		if r.StatusCode != http.StatusOK {
			return false
		}
		return json.NewDecoder(r.Body).Decode(&stock) == nil
	})
	if stock["productId"] != product.ID || stock["onHand"] != float64(0) {
		t.Fatalf("unexpected stock item: %v", stock)
	}
	t.Logf("stock item ok: %v", stock)

	// 5. one trace spans HTTP request, product-service and the inventory consumer
	waitFor(t, 60*time.Second, "trace with both services in Tempo", func() bool {
		r, err := http.Get(tempoURL + "/api/traces/" + traceID)
		if err != nil {
			return false
		}
		defer r.Body.Close()
		b, _ := io.ReadAll(r.Body)
		return r.StatusCode == http.StatusOK && bytes.Contains(b, []byte(`"product-service"`)) &&
			bytes.Contains(b, []byte(`"inventory-service"`)) && bytes.Contains(b, []byte("cf.product.events.v1 process"))
	})
	t.Logf("trace %s contains product-service and inventory-service spans", traceID)
}

func waitFor(t *testing.T, timeout time.Duration, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(time.Second)
	}
	t.Fatalf("timed out after %s waiting for %s", timeout, what)
}

func keys(m map[string]string) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
