// Package logging builds the structured JSON logger used by the service.
package logging

import (
	"io"
	"log/slog"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/infrastructure/telemetry"
)

// New returns a JSON slog logger that tags every record with the service name and, when a
// span is active in the context, its trace_id and span_id.
func New(w io.Writer, level slog.Level, service string) *slog.Logger {
	h := slog.NewJSONHandler(w, &slog.HandlerOptions{Level: level})
	return slog.New(telemetry.TraceHandler{Handler: h}).With("service", service)
}
