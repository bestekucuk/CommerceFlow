---
name: golang-development
description: Build a CommerceFlow Go service as its own Go module inside its services/*-service folder - project layout, configuration, structured logging with slog, context propagation, worker pools, graceful shutdown, HTTP server, Makefile and idiomatic table-driven tests. Use for inventory, shipping and notification services.
---

# Go service development

## Purpose

Give every Go service (inventory, shipping, notification) a consistent, idiomatic and
production-ready baseline: one module per service, explicit dependencies, context
everywhere, structured logs and a clean shutdown.

## When to use

- First code in a Go service folder.
- Adding workers, consumers or HTTP endpoints.
- Diagnosing leaks, hangs on shutdown or lost messages.

## Prerequisites

- Go 1.23+ (`go version`), Docker for Testcontainers.
- Service `CLAUDE.md`; `clean-architecture`; `idempotent-consumer`; `transactional-outbox`.

## Concepts and architecture

- **Module per service:** `services/inventory-service/go.mod` with module path
  `github.com/commerceflow/commerceflow/services/inventory-service`. No `go.work` joining
  services; no `replace` to sibling folders.
- **Composition root:** `cmd/<service>/main.go` builds config, logger, pools, adapters,
  use cases, then runs components under one `errgroup` bound to a signal context.
- **Context:** first parameter of every I/O function; carries deadlines, cancellation and
  trace context. Only `main` creates the root context.
- **Shutdown order:** stop accepting (HTTP, Kafka fetch) → drain in-flight work with a
  deadline → commit offsets → close pools → exit.

## Step-by-step workflow

1. `go mod init github.com/commerceflow/commerceflow/services/<name>-service`.
2. Create the layout below; put pure logic in `internal/domain`.
3. Implement `internal/platform/config` (env parsing with validation) and logging.
4. Implement adapters; inject them into application use cases via interfaces.
5. Write `main.go` with `signal.NotifyContext` and `errgroup`.
6. Add the Makefile; run `make lint test build`.
7. Add Dockerfile and CI (`docker-kubernetes`, `github-actions-cicd`).

## Practical code examples

`cmd/inventory-service/main.go`:

```go
func main() {
	if err := run(); err != nil {
		slog.Error("service stopped with error", "err", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel}))
	slog.SetDefault(logger.With("service", "inventory-service"))

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("connect db: %w", err)
	}
	defer pool.Close()

	reserve := application.NewReserveStock(postgres.NewStockRepository(pool), postgres.NewOutbox())
	consumer := kafka.NewCommandConsumer(cfg.Kafka, pool, reserve)
	srv := &http.Server{Addr: cfg.HTTPAddr, Handler: httpadapter.Router(pool), ReadHeaderTimeout: 5 * time.Second}

	g, gctx := errgroup.WithContext(ctx)
	g.Go(func() error { return consumer.Run(gctx) })
	g.Go(func() error {
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			return err
		}
		return nil
	})
	g.Go(func() error {
		<-gctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	})
	return g.Wait()
}
```

Bounded worker pool that preserves per-key ordering (same SKU → same worker):

```go
type Job struct {
	Key string
	Do  func(context.Context) error
}

func RunWorkers(ctx context.Context, n int, jobs <-chan Job) error {
	lanes := make([]chan Job, n)
	g, ctx := errgroup.WithContext(ctx)
	for i := range lanes {
		lanes[i] = make(chan Job, 16)
		lane := lanes[i]
		g.Go(func() error {
			for job := range lane {
				if err := job.Do(ctx); err != nil {
					return err
				}
			}
			return nil
		})
	}
	g.Go(func() error {
		defer func() {
			for _, l := range lanes {
				close(l)
			}
		}()
		for {
			select {
			case <-ctx.Done():
				return nil
			case job, ok := <-jobs:
				if !ok {
					return nil
				}
				h := fnv.New32a()
				h.Write([]byte(job.Key))
				lanes[h.Sum32()%uint32(n)] <- job
			}
		}
	})
	return g.Wait()
}
```

Config with validation:

```go
type Config struct {
	HTTPAddr        string
	DatabaseURL     string
	ShutdownTimeout time.Duration
	LogLevel        slog.Level
	Kafka           KafkaConfig
}

func Load() (Config, error) {
	c := Config{HTTPAddr: getenv("HTTP_ADDR", ":8083"), ShutdownTimeout: 20 * time.Second}
	c.DatabaseURL = os.Getenv("DATABASE_URL")
	if c.DatabaseURL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}
	// ... parse remaining fields, return all validation errors with errors.Join
	return c, nil
}
```

Table-driven test:

```go
func TestStockItem_Reserve(t *testing.T) {
	tests := []struct {
		name    string
		item    domain.StockItem
		qty     int
		wantErr error
	}{
		{"enough stock", domain.StockItem{OnHand: 5}, 3, nil},
		{"exactly available", domain.StockItem{OnHand: 3, Reserved: 1}, 2, nil},
		{"insufficient", domain.StockItem{OnHand: 1}, 2, domain.ErrInsufficientStock},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := tt.item.Reserve(domain.OrderID("o-1"), tt.qty)
			if !errors.Is(err, tt.wantErr) {
				t.Fatalf("Reserve() err = %v, want %v", err, tt.wantErr)
			}
		})
	}
}
```

`Makefile`:

```make
.PHONY: lint test build
lint:  ; go vet ./... && test -z "$$(gofmt -l .)"
test:  ; go test -race -count=1 ./...
build: ; CGO_ENABLED=0 go build -trimpath -o bin/inventory-service ./cmd/inventory-service
```

## Recommended project structure

```text
services/inventory-service/
  go.mod go.sum Makefile Dockerfile
  cmd/inventory-service/main.go
  internal/domain/            pure logic, stdlib only
  internal/application/       use cases + port interfaces
  internal/adapters/{http,kafka,postgres,redis}/
  internal/platform/{config,logging,telemetry}/
  migrations/                 0001_init.up.sql / .down.sql
```

## Best practices

- Return errors, wrap with `%w`, check with `errors.Is/As`; log once at the boundary.
- Accept interfaces, return structs; define interfaces where they are used.
- Every goroutine is started by an `errgroup` or has a documented owner and stop signal.
- Use `slog` with `ctx`-aware handlers to attach `trace_id` (`distributed-tracing`).
- Set timeouts on `http.Server` and all outbound clients.
- `go test -race` in CI.

## Anti-patterns

- `context.Background()` or `context.TODO()` below `main`.
- Fire-and-forget `go func()` without lifecycle.
- Package-level mutable globals (except the default logger set once in `main`).
- `panic` for expected errors; `log.Fatal` outside `main`.
- Unbounded goroutines per message.

## Failure scenarios

| Scenario | Symptom | Handling |
|---|---|---|
| SIGTERM during processing | Messages processed twice after restart | Drain with deadline, commit after tx; inbox makes reprocessing safe. |
| Goroutine leak | Memory/goroutine count grows | Tie to context; test with `goleak` in shutdown tests. |
| DB pool exhausted | Requests hang | Pool size ≥ workers + HTTP concurrency; context deadlines on queries. |
| Panic in worker | Process crashes | Recover at worker boundary, log, send message to DLT, keep running. |

## Testing strategy

- Table-driven unit tests for domain and application.
- Testcontainers-for-Go integration tests for postgres and kafka adapters (`testcontainers`).
- Shutdown test: start components, cancel context, assert return within timeout.
- Benchmarks for hot paths (`go test -bench=. -benchmem`).

## Definition of Done

- `make lint test build` passes from the service folder.
- No `replace` directives to sibling folders; no `go.work`.
- Graceful shutdown implemented and tested.
- Context passed through every I/O call; JSON structured logs.
