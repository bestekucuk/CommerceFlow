//go:build integration

// Package integration runs the service's adapters against real PostgreSQL
// (Testcontainers). Run with: go test -tags=integration ./tests/...
package integration

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/testcontainers/testcontainers-go"
	tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	"github.com/commerceflow/commerceflow/services/shipping-service/internal/infrastructure/postgres"
	transporthttp "github.com/commerceflow/commerceflow/services/shipping-service/internal/transport/http"
)

func TestReadinessAndMigrationsAgainstPostgres(t *testing.T) {
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	ctr, err := tcpostgres.Run(ctx, "postgres:16-alpine",
		tcpostgres.WithDatabase("shipping_db"),
		tcpostgres.WithUsername("shipping_migrator"),
		tcpostgres.WithPassword("integration-only"),
		testcontainers.WithWaitStrategy(wait.ForLog("database system is ready to accept connections").
			WithOccurrence(2).WithStartupTimeout(90*time.Second)),
	)
	if err != nil {
		t.Fatalf("start postgres: %v", err)
	}
	t.Cleanup(func() { _ = testcontainers.TerminateContainer(ctr) })

	dsn, err := ctr.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatalf("connection string: %v", err)
	}
	pool, err := postgres.NewPool(ctx, dsn)
	if err != nil {
		t.Fatalf("pool: %v", err)
	}
	t.Cleanup(pool.Close)

	up, err := os.ReadFile(filepath.Join("..", "..", "migrations", "000001_outbox_inbox.up.sql"))
	if err != nil {
		t.Fatalf("read migration: %v", err)
	}
	if _, err := pool.Exec(ctx, string(up)); err != nil {
		t.Fatalf("apply migration: %v", err)
	}
	var n int
	if err := pool.QueryRow(ctx, "SELECT count(*) FROM information_schema.tables WHERE table_name = 'outbox'").Scan(&n); err != nil || n != 1 {
		t.Fatalf("outbox table missing: n=%d err=%v", n, err)
	}

	rec := httptest.NewRecorder()
	transporthttp.NewRouter(pool).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/readyz", nil))
	if rec.Code != http.StatusOK || !strings.Contains(rec.Body.String(), "UP") {
		t.Fatalf("readyz = %d %s", rec.Code, rec.Body.String())
	}
}
