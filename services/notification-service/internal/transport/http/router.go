// Package http exposes the service's HTTP endpoints.
package http

import (
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"time"
)

// ReadinessChecker reports whether a dependency needed to serve traffic is reachable.
type ReadinessChecker interface {
	Ping(ctx context.Context) error
}

// NewRouter returns the HTTP handler with liveness (/healthz) and readiness (/readyz).
func NewRouter(db ReadinessChecker) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeStatus(w, http.StatusOK, "UP")
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := db.Ping(ctx); err != nil {
			slog.WarnContext(ctx, "readiness check failed", "dependency", "postgres", "err", err)
			writeStatus(w, http.StatusServiceUnavailable, "DOWN")
			return
		}
		writeStatus(w, http.StatusOK, "UP")
	})
	return mux
}

func writeStatus(w http.ResponseWriter, code int, status string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]string{"status": status})
}
