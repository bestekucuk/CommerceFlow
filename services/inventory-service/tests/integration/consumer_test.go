//go:build integration

package integration

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"os"
	"path/filepath"
	"sort"
	"sync/atomic"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/testutil"
	"github.com/testcontainers/testcontainers-go"
	tckafka "github.com/testcontainers/testcontainers-go/modules/kafka"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"
	"github.com/twmb/franz-go/pkg/kadm"
	"github.com/twmb/franz-go/pkg/kgo"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/application"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/kafka"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/postgres"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/testsupport"
)

const schemaID = 1

var (
	pool    *pgxpool.Pool
	brokers []string
	schema  string
)

// TestMain starts PostgreSQL and Kafka once for all consumer tests and applies the
// service's real migrations.
func TestMain(m *testing.M) {
	ctx := context.Background()
	code, err := setup(ctx, m)
	if err != nil {
		fmt.Fprintln(os.Stderr, "integration setup failed:", err)
		os.Exit(1)
	}
	os.Exit(code)
}

func setup(ctx context.Context, m *testing.M) (int, error) {
	pg, err := tcpostgres.Run(ctx, "postgres:16.4-alpine",
		tcpostgres.WithDatabase("inventory_db"), tcpostgres.WithUsername("inventory_migrator"),
		tcpostgres.WithPassword("integration-only"),
		testcontainers.WithWaitStrategy(wait.ForLog("database system is ready to accept connections").
			WithOccurrence(2).WithStartupTimeout(90*time.Second)))
	if err != nil {
		return 0, fmt.Errorf("postgres: %w", err)
	}
	defer func() { _ = testcontainers.TerminateContainer(pg) }()
	dsn, err := pg.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		return 0, err
	}
	if pool, err = pgxpool.New(ctx, dsn); err != nil {
		return 0, err
	}
	defer pool.Close()
	files, _ := filepath.Glob(filepath.Join("..", "..", "migrations", "*.up.sql"))
	sort.Strings(files)
	for _, f := range files {
		sql, err := os.ReadFile(f)
		if err != nil {
			return 0, err
		}
		if _, err := pool.Exec(ctx, string(sql)); err != nil {
			return 0, fmt.Errorf("migration %s: %w", f, err)
		}
	}

	kc, err := tckafka.Run(ctx, "confluentinc/confluent-local:7.5.0", tckafka.WithClusterID("inventory-it"))
	if err != nil {
		return 0, fmt.Errorf("kafka: %w", err)
	}
	defer func() { _ = testcontainers.TerminateContainer(kc) }()
	if brokers, err = kc.Brokers(ctx); err != nil {
		return 0, err
	}
	admin, err := kgo.NewClient(kgo.SeedBrokers(brokers...))
	if err != nil {
		return 0, err
	}
	if _, err := kadm.NewClient(admin).CreateTopics(ctx, 3, 1, nil, kafka.Topic, kafka.DLTTopic); err != nil {
		return 0, fmt.Errorf("create topics: %w", err)
	}
	admin.Close()

	if schema, err = testsupport.ProductCreatedSchema(); err != nil {
		return 0, err
	}
	return m.Run(), nil
}

// ---------------------------------------------------------------- helpers

type runningConsumer struct {
	consumer *kafka.Consumer
	metrics  *kafka.Metrics
	cancel   context.CancelFunc
	done     chan error
}

func startConsumer(t *testing.T, handler kafka.Handler) *runningConsumer {
	t.Helper()
	metrics := kafka.NewMetrics(prometheus.NewRegistry())
	c, err := kafka.NewConsumer(kafka.Config{Brokers: brokers, InitialBackoff: 100 * time.Millisecond, MaxBackoff: 400 * time.Millisecond},
		kafka.NewDecoder(testsupport.StaticRegistry{schemaID: schema}), handler, metrics,
		slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelWarn})))
	if err != nil {
		t.Fatal(err)
	}
	ctx, cancel := context.WithCancel(context.Background())
	rc := &runningConsumer{consumer: c, metrics: metrics, cancel: cancel, done: make(chan error, 1)}
	go func() { rc.done <- c.Run(ctx) }()
	t.Cleanup(func() { rc.stop(t) })
	return rc
}

// stop triggers graceful shutdown and waits for Run to return (idempotent).
func (rc *runningConsumer) stop(t *testing.T) {
	rc.cancel()
	select {
	case err, ok := <-rc.done:
		if ok && err != nil {
			t.Errorf("consumer returned error: %v", err)
		}
		close(rc.done)
	case <-time.After(30 * time.Second):
		t.Error("consumer did not shut down within 30s")
	default:
		// already stopped and drained
	}
}

func (rc *runningConsumer) count(outcome string) float64 {
	return testutil.ToFloat64(rc.metrics.Processed.WithLabelValues(kafka.Topic, outcome))
}

func produce(t *testing.T, key string, value []byte, eventType, id string) {
	t.Helper()
	cl, err := kgo.NewClient(kgo.SeedBrokers(brokers...))
	if err != nil {
		t.Fatal(err)
	}
	defer cl.Close()
	rec := &kgo.Record{Topic: kafka.Topic, Key: []byte(key), Value: value, Headers: []kgo.RecordHeader{
		{Key: "id", Value: []byte(id)}, {Key: "eventType", Value: []byte(eventType)},
		{Key: "traceparent", Value: []byte("00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01")},
	}}
	if err := cl.ProduceSync(context.Background(), rec).FirstErr(); err != nil {
		t.Fatal(err)
	}
}

func produceEvent(t *testing.T, e testsupport.Event) {
	t.Helper()
	value, err := testsupport.Encode(schema, schemaID, e)
	if err != nil {
		t.Fatal(err)
	}
	produce(t, e.AggregateID, value, e.EventType, e.EventID)
}

func uuid(n int) string { return fmt.Sprintf("0190d1c4-6b8c-7c3e-9f5e-%012d", n) }

var seq atomic.Int64

func next() int { return int(seq.Add(1)) + int(time.Now().UnixNano()%1_000_000)*100 }

func eventually(t *testing.T, what string, cond func() bool) {
	t.Helper()
	deadline := time.Now().Add(45 * time.Second)
	for time.Now().Before(deadline) {
		if cond() {
			return
		}
		time.Sleep(200 * time.Millisecond)
	}
	t.Fatalf("timed out waiting for %s", what)
}

func scalar(t *testing.T, sql string, args ...any) int {
	t.Helper()
	var n int
	if err := pool.QueryRow(context.Background(), sql, args...).Scan(&n); err != nil {
		t.Fatal(err)
	}
	return n
}

func stockItems(t *testing.T, productID string) int {
	return scalar(t, `SELECT count(*) FROM stock_item WHERE product_id = $1`, productID)
}

// ---------------------------------------------------------------- tests

func TestConsumer_CreatesStockItemsForProductCreated(t *testing.T) {
	n := next()
	e := testsupport.ValidEvent(uuid(n), uuid(n+1), fmt.Sprintf("SKU-%d-A", n), fmt.Sprintf("SKU-%d-B", n))
	rc := startConsumer(t, application.NewRegisterProduct(postgres.NewStore(pool)))

	produceEvent(t, e)

	eventually(t, "two stock items", func() bool { return stockItems(t, e.ProductID) == 2 })
	if got := scalar(t, `SELECT count(*) FROM inbox WHERE message_id = $1`, e.EventID); got != 1 {
		t.Fatalf("inbox rows = %d, want 1", got)
	}
	if got := scalar(t, `SELECT on_hand FROM stock_item WHERE sku = $1`, e.SKUs[0]); got != 0 {
		t.Fatalf("on_hand = %d, want 0", got)
	}
	eventually(t, "processed metric", func() bool { return rc.count("processed") >= 1 })
}

func TestConsumer_DuplicateDeliveryHasOneEffect(t *testing.T) {
	n := next()
	e := testsupport.ValidEvent(uuid(n), uuid(n+1), fmt.Sprintf("SKU-%d-D", n))
	rc := startConsumer(t, application.NewRegisterProduct(postgres.NewStore(pool)))

	produceEvent(t, e)
	produceEvent(t, e) // same eventId, e.g. after a Debezium restart

	eventually(t, "duplicate detected", func() bool { return rc.count("duplicate") >= 1 })
	if got := stockItems(t, e.ProductID); got != 1 {
		t.Fatalf("stock items = %d, want 1", got)
	}
	if got := scalar(t, `SELECT count(*) FROM inbox WHERE message_id = $1`, e.EventID); got != 1 {
		t.Fatalf("inbox rows = %d, want 1", got)
	}
}

func TestConsumer_PoisonMessageIsDeadLetteredAndPartitionContinues(t *testing.T) {
	n := next()
	key := uuid(n + 1)
	rc := startConsumer(t, application.NewRegisterProduct(postgres.NewStore(pool)))

	produce(t, key, []byte("not avro"), "ProductCreated", uuid(n))             // undecodable
	good := testsupport.ValidEvent(uuid(n+2), key, fmt.Sprintf("SKU-%d-P", n)) // same key -> same partition, after it
	produceEvent(t, good)

	eventually(t, "valid record after poison processed", func() bool { return stockItems(t, key) == 1 })
	if rc.count("dlt") < 1 {
		t.Fatal("poison message was not dead-lettered")
	}

	cl, err := kgo.NewClient(kgo.SeedBrokers(brokers...), kgo.ConsumeTopics(kafka.DLTTopic),
		kgo.ConsumeResetOffset(kgo.NewOffset().AtStart()))
	if err != nil {
		t.Fatal(err)
	}
	defer cl.Close()
	found := false
	ctx, cancel := context.WithTimeout(context.Background(), 20*time.Second)
	defer cancel()
	for !found && ctx.Err() == nil {
		cl.PollFetches(ctx).EachRecord(func(r *kgo.Record) {
			if string(r.Key) != key {
				return
			}
			h := map[string]string{}
			for _, x := range r.Headers {
				h[x.Key] = string(x.Value)
			}
			if h["dlt-original-topic"] == kafka.Topic && h["dlt-error"] != "" && h["id"] == uuid(n) && string(r.Value) == "not avro" {
				found = true
			}
		})
	}
	if !found {
		t.Fatal("DLT record with original bytes and diagnostic headers not found")
	}
}

// flakyHandler fails the first n calls with a transient error.
type flakyHandler struct {
	next  kafka.Handler
	fails atomic.Int32
}

func (f *flakyHandler) Handle(ctx context.Context, e application.ProductCreated) (application.Outcome, error) {
	if f.fails.Add(-1) >= 0 {
		return "", errors.New("simulated: database connection reset")
	}
	return f.next.Handle(ctx, e)
}

func TestConsumer_RetriesTransientFailuresWithoutSkipping(t *testing.T) {
	n := next()
	e := testsupport.ValidEvent(uuid(n), uuid(n+1), fmt.Sprintf("SKU-%d-T", n))
	flaky := &flakyHandler{next: application.NewRegisterProduct(postgres.NewStore(pool))}
	flaky.fails.Store(3)
	rc := startConsumer(t, flaky)

	produceEvent(t, e)

	eventually(t, "processed after retries", func() bool { return stockItems(t, e.ProductID) == 1 })
	if got := testutil.ToFloat64(rc.metrics.Retries.WithLabelValues(kafka.Topic)); got != 3 {
		t.Fatalf("retries = %v, want 3", got)
	}
	if rc.count("dlt") != 0 {
		t.Fatal("transient failure must not dead-letter")
	}
	if !rc.consumer.Healthy() {
		t.Fatal("consumer should be healthy again after recovery")
	}
}

func TestConsumer_RestartResumesFromCommittedOffsets(t *testing.T) {
	n := next()
	store := postgres.NewStore(pool)
	a := testsupport.ValidEvent(uuid(n), uuid(n+1), fmt.Sprintf("SKU-%d-RA", n))
	b := testsupport.ValidEvent(uuid(n+2), uuid(n+3), fmt.Sprintf("SKU-%d-RB", n))
	c := testsupport.ValidEvent(uuid(n+4), uuid(n+5), fmt.Sprintf("SKU-%d-RC", n))

	first := startConsumer(t, application.NewRegisterProduct(store))
	produceEvent(t, a)
	eventually(t, "A processed", func() bool { return stockItems(t, a.ProductID) == 1 })
	first.stop(t) // graceful shutdown: commits A's offset and leaves the group

	produceEvent(t, b) // produced while no consumer is running
	produceEvent(t, c)

	second := startConsumer(t, application.NewRegisterProduct(store))
	eventually(t, "B and C processed after restart", func() bool {
		return stockItems(t, b.ProductID) == 1 && stockItems(t, c.ProductID) == 1
	})
	if d := second.count("duplicate"); d != 0 {
		t.Fatalf("restarted consumer re-read %v already committed record(s)", d)
	}
	if got := scalar(t, `SELECT count(*) FROM inbox WHERE message_id = ANY($1)`, []string{a.EventID, b.EventID, c.EventID}); got != 3 {
		t.Fatalf("inbox rows = %d, want 3", got)
	}
}

func TestConsumer_PermanentDataErrorsAreDeadLettered(t *testing.T) {
	n := next()
	rc := startConsumer(t, application.NewRegisterProduct(postgres.NewStore(pool)))

	// event id is not a UUID: the Avro uuid logical type is not enforced on the wire
	bad := testsupport.ValidEvent("not-a-uuid", uuid(n+1), fmt.Sprintf("SKU-%d-U", n))
	produceEvent(t, bad)
	// SKU already owned by another product (catalog drift)
	owner := testsupport.ValidEvent(uuid(n+2), uuid(n+3), fmt.Sprintf("SKU-%d-X", n))
	produceEvent(t, owner)
	eventually(t, "owner processed", func() bool { return stockItems(t, owner.ProductID) == 1 })
	thief := testsupport.ValidEvent(uuid(n+4), uuid(n+5), fmt.Sprintf("SKU-%d-X", n))
	produceEvent(t, thief)

	eventually(t, "both bad events dead-lettered", func() bool { return rc.count("dlt") >= 2 })
	if got := testutil.ToFloat64(rc.metrics.Retries.WithLabelValues(kafka.Topic)); got != 0 {
		t.Fatalf("permanent errors were retried %v times", got)
	}
	if got := stockItems(t, thief.ProductID); got != 0 {
		t.Fatalf("SKU of another product was attached to %s", thief.ProductID)
	}
	if got := scalar(t, `SELECT count(*) FROM inbox WHERE message_id = $1`, thief.EventID); got != 0 {
		t.Fatalf("dead-lettered event must not be recorded in the inbox")
	}
}
