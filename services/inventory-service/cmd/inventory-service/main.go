// Command inventory-service runs the inventory bounded context: the ProductCreated
// consumer, HTTP health/metrics/stock endpoints and a PostgreSQL pool, with graceful
// shutdown on SIGINT/SIGTERM.
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

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/collectors"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"github.com/twmb/franz-go/pkg/sr"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/application"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/config"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/kafka"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/logging"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/postgres"
	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/telemetry"
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
	log := logging.New(os.Stdout, cfg.LogLevel, serviceName)
	slog.SetDefault(log)

	flushTraces, err := telemetry.Setup(ctx, serviceName)
	if err != nil {
		return fmt.Errorf("telemetry: %w", err)
	}

	pool, err := postgres.NewPool(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("create database pool: %w", err)
	}
	defer pool.Close()
	store := postgres.NewStore(pool)

	registry := prometheus.NewRegistry()
	registry.MustRegister(collectors.NewGoCollector(), collectors.NewProcessCollector(collectors.ProcessCollectorOpts{}))
	metrics := kafka.NewMetrics(registry)

	srClient, err := sr.NewClient(sr.URLs(cfg.SchemaRegistryURL))
	if err != nil {
		return fmt.Errorf("schema registry client: %w", err)
	}
	consumer, err := kafka.NewConsumer(kafka.Config{Brokers: cfg.KafkaBrokers, ShutdownGrace: cfg.ShutdownTimeout / 2},
		kafka.NewDecoder(srClient), application.NewRegisterProduct(store), metrics, log)
	if err != nil {
		return err
	}

	srv := &http.Server{
		Addr: cfg.HTTPAddr,
		Handler: transporthttp.NewRouter(pool, transporthttp.Options{
			Stock:           store,
			ConsumerHealthy: consumer.Healthy,
			Metrics:         promhttp.HandlerFor(registry, promhttp.HandlerOpts{}),
		}),
		ReadHeaderTimeout: 5 * time.Second,
	}

	serveErr := make(chan error, 1)
	go func() {
		log.InfoContext(ctx, "http server listening", "addr", cfg.HTTPAddr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			serveErr <- err
		}
		close(serveErr)
	}()

	consumerDone := make(chan error, 1)
	go func() {
		log.InfoContext(ctx, "consumer started", "topic", kafka.Topic, "group", kafka.Group)
		consumerDone <- consumer.Run(ctx)
	}()

	select {
	case <-ctx.Done():
		log.Info("shutdown signal received")
	case err := <-serveErr:
		if err != nil {
			stop()
			<-consumerDone
			return fmt.Errorf("http server: %w", err)
		}
	case err := <-consumerDone:
		stop()
		if err != nil {
			return fmt.Errorf("consumer: %w", err)
		}
	}

	// Order: stop consuming (finishes the in-flight record, commits offsets), then HTTP,
	// then flush traces.
	shutdownCtx, cancel := context.WithTimeout(context.Background(), cfg.ShutdownTimeout)
	defer cancel()
	select {
	case <-consumerDone:
	case <-shutdownCtx.Done():
		log.Warn("consumer did not stop in time")
	}
	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("graceful shutdown: %w", err)
	}
	if err := flushTraces(shutdownCtx); err != nil {
		log.Warn("trace flush failed", "err", err)
	}
	log.Info("stopped")
	return nil
}
