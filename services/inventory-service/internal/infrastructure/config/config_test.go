package config

import (
	"log/slog"
	"testing"
	"time"
)

func env(m map[string]string) func(string) string {
	return func(k string) string { return m[k] }
}

func TestLoad(t *testing.T) {
	tests := []struct {
		name    string
		env     map[string]string
		wantErr bool
		check   func(t *testing.T, c Config)
	}{
		{
			name: "defaults",
			env:  map[string]string{"DATABASE_URL": "postgres://localhost/db", "KAFKA_BROKERS": "k:9092", "SCHEMA_REGISTRY_URL": "http://sr"},
			check: func(t *testing.T, c Config) {
				if c.HTTPAddr != ":9999" || c.ShutdownTimeout != 20*time.Second || c.LogLevel != slog.LevelInfo {
					t.Fatalf("unexpected defaults: %+v", c)
				}
			},
		},
		{
			name: "overrides",
			env:  map[string]string{"DATABASE_URL": "x", "KAFKA_BROKERS": "a:1, b:2", "SCHEMA_REGISTRY_URL": "http://sr", "HTTP_ADDR": ":1", "SHUTDOWN_TIMEOUT": "5s", "LOG_LEVEL": "debug"},
			check: func(t *testing.T, c Config) {
				if c.HTTPAddr != ":1" || c.ShutdownTimeout != 5*time.Second || c.LogLevel != slog.LevelDebug || len(c.KafkaBrokers) != 2 || c.KafkaBrokers[1] != "b:2" {
					t.Fatalf("overrides not applied: %+v", c)
				}
			},
		},
		{name: "missing database url", env: map[string]string{}, wantErr: true},
		{name: "invalid timeout", env: map[string]string{"DATABASE_URL": "x", "KAFKA_BROKERS": "k:1", "SCHEMA_REGISTRY_URL": "http://sr", "SHUTDOWN_TIMEOUT": "soon"}, wantErr: true},
		{name: "missing kafka", env: map[string]string{"DATABASE_URL": "x", "SCHEMA_REGISTRY_URL": "http://sr"}, wantErr: true},
		{name: "invalid log level", env: map[string]string{"DATABASE_URL": "x", "LOG_LEVEL": "loud"}, wantErr: true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			c, err := Load(env(tt.env), ":9999")
			if (err != nil) != tt.wantErr {
				t.Fatalf("Load() err = %v, wantErr %v", err, tt.wantErr)
			}
			if tt.check != nil {
				tt.check(t, c)
			}
		})
	}
}
