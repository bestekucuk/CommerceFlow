// Command inventory-service starts the inventory service: HTTP health endpoints and a PostgreSQL
// pool, with graceful shutdown on SIGINT/SIGTERM.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/config"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/logging"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/postgres"
	transporthttp "github.com/commerceflow/commerceflow/services/inventory-service/internal/transport/http"
)

const serviceName = "inventory-service"

func main() {
	if err := run(); err != nil {
		slog.Error("service stopped with error", "err", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	cfg, err := config.Load(os.Getenv, ":8083")
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}
	slog.SetDefault(logging.New(os.Stdout, cfg.LogLevel, serviceName))

	pool, err := postgres.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("create database pool: %w", err)
	}
	defer pool.Close()

	srv := &http.Server{
		Addr:              cfg.HTTPAddr,
		Handler:           transporthttp.NewRouter(pool),
		ReadHeaderTimeout: 5 * time.Second,
	}

	serveErr := make(chan error, 1)
	go func() {
		slog.InfoContext(ctx, "http server listening", "addr", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
		}
		close(serveErr)
	}()

	select {
	case <-ctx.Done():
		slog.Info("shutdown signal received")
	case err := <-serveErr:
		if err != nil {
			return fmt.Errorf("http server: %w", err)
		}
	}

	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("graceful shutdown: %w", err)
	}
	slog.Info("stopped")
	return nil
}
