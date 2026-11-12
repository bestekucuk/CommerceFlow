---
name: observability
description: Make CommerceFlow services observable with OpenTelemetry, Prometheus, Grafana, Loki and Tempo - RED/USE metrics, business and messaging metrics (consumer lag, DLT, outbox/slot lag, stuck sagas), structured JSON logs with trace ids, the collector pipeline, dashboards and alert rules. Use when adding a service, an endpoint, a consumer, or when defining SLOs and alerts.
---

# Observability

## Purpose

Answer "is it working, and if not, where?" for every service and for the saga as a whole,
using metrics for detection, traces for location and logs for detail.

## When to use

- New service, endpoint or consumer.
- Defining SLOs, dashboards or alerts.
- Incident analysis.

## Prerequisites

- `distributed-tracing` (trace context everywhere).
- Monitoring stack config in `infrastructure/monitoring/` (owner: `devops-engineer`).

## Concepts and architecture

```text
services --OTLP (traces, metrics optional)--> otel-collector --> Tempo (traces)
services --/metrics, /actuator/prometheus--> Prometheus --> Grafana (dashboards, alerts)
services --stdout JSON logs--> collector/promtail --> Loki
Grafana links: metric exemplar -> trace (Tempo) -> logs (Loki by trace_id)
```

**Metric sets**

| Kind | Metrics |
|---|---|
| RED per endpoint | request rate, error rate, duration histogram (`http_server_requests_seconds` / `http_server_request_duration_seconds`) |
| USE per resource | DB pool active/idle/pending, JVM heap/GC, Go goroutines, CPU, memory |
| Messaging | consumer lag per group/partition, processing duration, retries, DLT sends, inbox duplicates |
| CDC | replication slot lag bytes, connector status, outbox row count/age |
| Business | orders placed/confirmed/rejected, saga duration, sagas past deadline |

**Logs:** JSON, one line per event, fields `timestamp`, `level`, `service`, `trace_id`,
`span_id`, `message`, domain IDs (`orderId`), never PII or secrets.

## Step-by-step workflow

1. Expose metrics (Actuator Prometheus / Go `promhttp`).
2. Add business and messaging metrics in adapters (not in the domain).
3. Configure JSON logs with trace ids.
4. Register the service in Prometheus scrape config and the collector.
5. Add/extend the service dashboard (RED + messaging + business).
6. Add alerts for SLO burn, DLT arrivals, lag, slot lag, stuck sagas.
7. Verify in Grafana with a local load run.

## Practical code examples

Kotlin (Micrometer) business metrics:

```kotlin
@Component
class SagaMetrics(registry: MeterRegistry) {
    private val confirmed = registry.counter("commerceflow_orders_total", "outcome", "confirmed")
    private val rejected = registry.counter("commerceflow_orders_total", "outcome", "rejected")
    private val duration = Timer.builder("commerceflow_saga_duration_seconds")
        .publishPercentileHistogram().register(registry)

    fun completed(outcome: String, startedAt: Instant, now: Instant) {
        (if (outcome == "CONFIRMED") confirmed else rejected).increment()
        duration.record(Duration.between(startedAt, now))
    }
}
```

Go (Prometheus client):

```go
var (
	messagesProcessed = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "commerceflow_messages_processed_total", Help: "Messages processed by outcome",
	}, []string{"topic", "outcome"}) // outcome: ok, duplicate, dlt
	processingSeconds = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name: "commerceflow_message_processing_seconds", Buckets: prometheus.DefBuckets,
	}, []string{"topic"})
)

mux.Handle("/metrics", promhttp.Handler())
```

Logback JSON with trace ids (Spring Boot 3.4+ structured logging):

```yaml
logging:
  structured:
    format:
      console: ecs        # or logstash; trace/span ids added by Micrometer Tracing / OTel agent MDC
```

Go slog handler adding trace ids:

```go
type traceHandler struct{ slog.Handler }

func (h traceHandler) Handle(ctx context.Context, r slog.Record) error {
	if sc := trace.SpanContextFromContext(ctx); sc.IsValid() {
		r.AddAttrs(slog.String("trace_id", sc.TraceID().String()), slog.String("span_id", sc.SpanID().String()))
	}
	return h.Handler.Handle(ctx, r)
}

func (h traceHandler) WithAttrs(a []slog.Attr) slog.Handler { return traceHandler{h.Handler.WithAttrs(a)} }
func (h traceHandler) WithGroup(n string) slog.Handler       { return traceHandler{h.Handler.WithGroup(n)} }
```

Alert rules (`infrastructure/monitoring/prometheus/alerts.yml`):

```yaml
groups:
  - name: commerceflow-messaging
    rules:
      - alert: DeadLetterMessages
        expr: increase(commerceflow_messages_processed_total{outcome="dlt"}[5m]) > 0
        labels: { severity: page }
        annotations: { summary: "DLT messages on {{ $labels.topic }}", runbook: "docs/runbooks/dlt-replay.md" }
      - alert: ReplicationSlotLagHigh
        expr: pg_replication_slots_pg_wal_lsn_diff > 1e9       # from postgres_exporter custom query
        for: 5m
        labels: { severity: page }
      - alert: SagasPastDeadline
        expr: commerceflow_sagas_past_deadline > 0
        for: 2m
        labels: { severity: ticket }
      - alert: ConsumerLagHigh
        expr: sum by (group) (kafka_consumergroup_lag) > 1000   # kafka-exporter
        for: 10m
        labels: { severity: ticket }
```

Collector pipeline: see `reference/otel-collector.yaml` in this skill folder.

## Recommended project structure

```text
infrastructure/monitoring/
  otel-collector.yaml
  prometheus/prometheus.yml  prometheus/alerts.yml
  grafana/provisioning/{datasources,dashboards}/  grafana/dashboards/<service>.json
  loki/  tempo/
```

## Best practices

- Prefix custom metrics with `commerceflow_`; low-cardinality labels only (no order IDs).
- Histograms for latency; alert on SLO burn rates rather than single spikes.
- Every alert links a runbook in `docs/runbooks/`.
- Dashboards per service with the same layout (RED, resources, messaging, business).
- Exemplars enabled to jump from latency spikes to traces.

## Anti-patterns

- Logging instead of metrics for counts and rates.
- High-cardinality labels (customer id, SKU) on metrics.
- Alerts without an owner or runbook.
- PII in logs; multi-line stack traces split into many log lines.

## Failure scenarios

| Symptom | Where to look |
|---|---|
| Orders stuck PENDING | `commerceflow_sagas_past_deadline`, consumer lag of order-service, slot lag of inventory/payment outboxes. |
| Latency spike | Exemplar → trace → slow span (DB? downstream?) → logs by trace_id. |
| Silent data loss suspicion | Outbox row count vs topic offsets; DLT counts; inbox duplicates. |

## Testing strategy

- Unit-test metric increments in adapters where logic decides the outcome label.
- Local verification: run k6 smoke and inspect dashboards.
- Alert rules tested with `promtool test rules`.

## Definition of Done

- Service exposes RED, resource, messaging and relevant business metrics.
- JSON logs include trace ids and no PII.
- Scraped by Prometheus; dashboard and alerts with runbook links exist.
- Alert rules pass `promtool check rules`.
