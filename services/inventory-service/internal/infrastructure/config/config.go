// Package config loads service configuration from environment variables.
package config

import (
	"errors"
	"fmt"
	"log/slog"
	"strings"
	"time"
)

// Config is the validated runtime configuration.
type Config struct {
	HTTPAddr          string
	DatabaseURL       string
	KafkaBrokers      []string
	SchemaRegistryURL string
	ShutdownTimeout   time.Duration
	LogLevel          slog.Level
}

// Load reads configuration through getenv (os.Getenv in production) and validates it.
func Load(getenv func(string) string, defaultAddr string) (Config, error) {
	cfg := Config{HTTPAddr: defaultAddr, ShutdownTimeout: 20 * time.Second, LogLevel: slog.LevelInfo}
	var errs []error

	if v := getenv("HTTP_ADDR"); v != "" {
		cfg.HTTPAddr = v
	}
	cfg.DatabaseURL = getenv("DATABASE_URL")
	if cfg.DatabaseURL == "" {
		errs = append(errs, errors.New("DATABASE_URL is required"))
	}
	for _, b := range strings.Split(getenv("KAFKA_BROKERS"), ",") {
		if b = strings.TrimSpace(b); b != "" {
			cfg.KafkaBrokers = append(cfg.KafkaBrokers, b)
		}
	}
	if len(cfg.KafkaBrokers) == 0 {
		errs = append(errs, errors.New("KAFKA_BROKERS is required (comma-separated host:port)"))
	}
	cfg.SchemaRegistryURL = getenv("SCHEMA_REGISTRY_URL")
	if cfg.SchemaRegistryURL == "" {
		errs = append(errs, errors.New("SCHEMA_REGISTRY_URL is required"))
	}
	if v := getenv("SHUTDOWN_TIMEOUT"); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil || d <= 0 {
			errs = append(errs, fmt.Errorf("SHUTDOWN_TIMEOUT must be a positive duration, got %q", v))
		} else {
			cfg.ShutdownTimeout = d
		}
	}
	if v := getenv("LOG_LEVEL"); v != "" {
		if err := cfg.LogLevel.UnmarshalText([]byte(v)); err != nil {
			errs = append(errs, fmt.Errorf("LOG_LEVEL: %w", err))
		}
	}
	return cfg, errors.Join(errs...)
}
