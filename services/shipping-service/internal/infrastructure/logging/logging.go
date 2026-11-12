// Package logging builds the structured JSON logger used by the service.
package logging

import (
	"io"
	"log/slog"
)

// New returns a JSON slog logger that tags every record with the service name.
func New(w io.Writer, level slog.Level, service string) *slog.Logger {
	return slog.New(slog.NewJSONHandler(w, &slog.HandlerOptions{Level: level})).With("service", service)
}
