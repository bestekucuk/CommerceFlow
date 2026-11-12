package http

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type fakeDB struct{ err error }

func (f fakeDB) Ping(context.Context) error { return f.err }

func TestRouter(t *testing.T) {
	tests := []struct {
		name     string
		path     string
		db       fakeDB
		wantCode int
		wantBody string
	}{
		{"liveness ignores database", "/healthz", fakeDB{err: errors.New("down")}, http.StatusOK, "UP"},
		{"readiness up", "/readyz", fakeDB{}, http.StatusOK, "UP"},
		{"readiness down", "/readyz", fakeDB{err: errors.New("down")}, http.StatusServiceUnavailable, "DOWN"},
		{"unknown path", "/nope", fakeDB{}, http.StatusNotFound, ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rec := httptest.NewRecorder()
			NewRouter(tt.db).ServeHTTP(rec, httptest.NewRequest(http.MethodGet, tt.path, nil))
			if rec.Code != tt.wantCode {
				t.Fatalf("code = %d, want %d", rec.Code, tt.wantCode)
			}
			if !strings.Contains(rec.Body.String(), tt.wantBody) {
				t.Fatalf("body = %q, want it to contain %q", rec.Body.String(), tt.wantBody)
			}
		})
	}
}
