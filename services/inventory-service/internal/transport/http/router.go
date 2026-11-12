// Package http exposes the service's HTTP endpoints.
package http

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"time"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/domain"
)

// ReadinessChecker reports whether a dependency needed to serve traffic is reachable.
type ReadinessChecker interface {
	Ping(ctx context.Context) error
}

// StockReader reads stock items (read-only API); unknown SKUs return domain.ErrNotFound.
type StockReader interface {
	StockBySKU(ctx context.Context, sku string) (domain.StockItem, error)
}

// Options are the optional parts of the router.
type Options struct {
	Stock StockReader
	// ConsumerHealthy is false while the Kafka consumer retries a transient failure.
	ConsumerHealthy func() bool
	Metrics         http.Handler
}

// NewRouter returns the HTTP handler: /healthz (liveness), /readyz (database and consumer),
// /metrics (Prometheus) and GET /v1/stock/{sku}.
func NewRouter(db ReadinessChecker, opts ...Options) http.Handler {
	var o Options
	if len(opts) > 0 {
		o = opts[0]
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "UP"})
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		if err := db.Ping(ctx); err != nil {
			slog.WarnContext(ctx, "readiness check failed", "dependency", "postgres", "err", err)
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "DOWN"})
			return
		}
		if o.ConsumerHealthy != nil && !o.ConsumerHealthy() {
			writeJSON(w, http.StatusServiceUnavailable, map[string]string{"status": "DOWN", "reason": "consumer retrying"})
			return
		}
		writeJSON(w, http.StatusOK, map[string]string{"status": "UP"})
	})
	if o.Metrics != nil {
		mux.Handle("GET /metrics", o.Metrics)
	}
	if o.Stock != nil {
		mux.HandleFunc("GET /v1/stock/{sku}", func(w http.ResponseWriter, r *http.Request) {
			item, err := o.Stock.StockBySKU(r.Context(), r.PathValue("sku"))
			switch {
			case errors.Is(err, domain.ErrNotFound):
				writeProblem(w, http.StatusNotFound, "not-found", "SKU not found")
			case err != nil:
				slog.ErrorContext(r.Context(), "read stock failed", "err", err)
				writeProblem(w, http.StatusInternalServerError, "internal", "Internal error")
			default:
				writeJSON(w, http.StatusOK, map[string]any{
					"sku": item.SKU, "productId": item.ProductID, "onHand": item.OnHand,
					"reserved": item.Reserved, "available": item.Available(),
				})
			}
		})
	}
	return mux
}

func writeJSON(w http.ResponseWriter, code int, body any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(body)
}

func writeProblem(w http.ResponseWriter, code int, kind, title string) {
	w.Header().Set("Content-Type", "application/problem+json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(map[string]any{
		"type": "https://commerceflow.dev/problems/" + kind, "title": title, "status": code,
	})
}
