---
name: distributed-tracing
description: Trace CommerceFlow requests end to end with OpenTelemetry and W3C Trace Context - Java agent/Spring instrumentation, Go SDK setup, HTTP propagation, carrying traceparent through the outbox row and Debezium headers across the asynchronous hop, consumer span links/parents, span naming and attributes, sampling and trace-log correlation. Use when adding a service, an outbound call, a producer or a consumer.
---

# Distributed tracing

## Purpose

Follow one customer action — "place order" — through storefront, order-service, the
outbox, Debezium, Kafka, inventory and payment, and back, in a single trace in Tempo.

## When to use

- Bootstrapping telemetry in a service.
- Adding outbound HTTP calls, outbox writes or consumers.
- Debugging where time is spent or where a flow breaks.

## Prerequisites

- Collector reachable (`OTEL_EXPORTER_OTLP_ENDPOINT`), see `observability`.
- `transactional-outbox` (the `trace_parent` column), `debezium-cdc` (header mapping).

## Concepts and architecture

```text
browser ──traceparent──> order-service HTTP span
   └─ use case span ── outbox row.trace_parent = current traceparent
        WAL ─> Debezium (no tracing) ─> Kafka record header "traceparent"
             └─ inventory-service consumer span (child of the producing span)
                  └─ outbox row ─> ... reply ─> order-service consumer span
```

- **W3C Trace Context** (`traceparent`, `tracestate`) is the only propagation format.
- **The async hop:** Debezium does not participate in tracing; the outbox carries the
  context in `trace_parent`, the Outbox Event Router copies it into the `traceparent` Kafka
  header, and consumers extract it.
- **Parent vs link:** for one-to-one command/reply, make the consumer span a child (one
  trace for the saga). For fan-out (one event, many consumers, possibly much later), a child
  is still fine; for batch processing use span links.
- **Resource attributes:** `service.name` (= folder name), `service.version` (git SHA),
  `deployment.environment`.
- **Sampling:** parent-based; head sampling 100 % locally, ratio in production (decide per
  environment); errors kept via tail sampling in the collector if needed.

## Step-by-step workflow

1. Enable instrumentation: OTel Java agent (Kotlin) or SDK setup (Go).
2. Set resource attributes via env vars.
3. Ensure HTTP clients/servers are instrumented (agent / `otelhttp`).
4. Write `traceparent` to the outbox in producers.
5. Extract `traceparent` in consumers and start a consumer span.
6. Add business attributes on key spans (`order.id`), never PII.
7. Verify in Tempo: one trace spans HTTP → outbox → consumer.

## Practical code examples

Kotlin with the Java agent (Dockerfile / Compose env):

```dockerfile
ADD https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v2.9.0/opentelemetry-javaagent.jar /otel/agent.jar
ENV JAVA_TOOL_OPTIONS="-javaagent:/otel/agent.jar"
```

```yaml
environment:
  OTEL_SERVICE_NAME: order-service
  OTEL_EXPORTER_OTLP_ENDPOINT: http://otel-collector:4317
  OTEL_EXPORTER_OTLP_PROTOCOL: grpc
  OTEL_RESOURCE_ATTRIBUTES: deployment.environment=local,service.version=${GIT_SHA:-dev}
  OTEL_METRICS_EXPORTER: none        # metrics via Prometheus scrape
  OTEL_LOGS_EXPORTER: none
```

The agent instruments Spring MVC, JDBC, `RestClient` and Spring Kafka listeners, and its
Kafka instrumentation extracts the `traceparent` header automatically, so Debezium-produced
records continue the producer's trace.

Capturing the context for the outbox (Kotlin, see `transactional-outbox`):

```kotlin
fun currentTraceParent(): String? {
    val carrier = HashMap<String, String>()
    GlobalOpenTelemetry.getPropagators().textMapPropagator.inject(Context.current(), carrier) { c, k, v -> c!![k] = v }
    return carrier["traceparent"]
}
```

Adding business attributes:

```kotlin
Span.current().setAttribute("commerceflow.order.id", order.id.value.toString())
```

Go SDK setup (`internal/platform/telemetry`):

```go
func Setup(ctx context.Context, serviceName, version string) (shutdown func(context.Context) error, err error) {
	exp, err := otlptracegrpc.New(ctx) // reads OTEL_EXPORTER_OTLP_ENDPOINT
	if err != nil {
		return nil, fmt.Errorf("otlp exporter: %w", err)
	}
	res, err := resource.Merge(resource.Default(), resource.NewWithAttributes(semconv.SchemaURL,
		semconv.ServiceName(serviceName), semconv.ServiceVersion(version)))
	if err != nil {
		return nil, err
	}
	tp := sdktrace.NewTracerProvider(
		sdktrace.WithBatcher(exp),
		sdktrace.WithResource(res),
		sdktrace.WithSampler(sdktrace.ParentBased(sdktrace.TraceIDRatioBased(1.0))),
	)
	otel.SetTracerProvider(tp)
	otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(propagation.TraceContext{}, propagation.Baggage{}))
	return tp.Shutdown, nil
}
```

HTTP server/client: wrap with `otelhttp.NewHandler(mux, "inventory-service")` and
`&http.Client{Transport: otelhttp.NewTransport(http.DefaultTransport)}`.

Consumer span from Kafka headers (franz-go):

```go
type headerCarrier []kgo.RecordHeader

func (h headerCarrier) Get(key string) string {
	for _, hd := range h {
		if strings.EqualFold(hd.Key, key) {
			return string(hd.Value)
		}
	}
	return ""
}
func (h headerCarrier) Set(string, string) {}
func (h headerCarrier) Keys() []string {
	keys := make([]string, 0, len(h))
	for _, hd := range h {
		keys = append(keys, hd.Key)
	}
	return keys
}

var tracer = otel.Tracer("inventory-service/kafka")

func (c *CommandConsumer) handleTraced(ctx context.Context, r *kgo.Record) error {
	ctx = otel.GetTextMapPropagator().Extract(ctx, headerCarrier(r.Headers))
	ctx, span := tracer.Start(ctx, r.Topic+" process",
		trace.WithSpanKind(trace.SpanKindConsumer),
		trace.WithAttributes(
			semconv.MessagingSystemKafka,
			attribute.String("messaging.destination.name", r.Topic),
			attribute.String("messaging.message.id", headerCarrier(r.Headers).Get("id")),
		))
	defer span.End()
	if err := c.handleWithRetry(ctx, r); err != nil {
		span.RecordError(err)
		span.SetStatus(codes.Error, err.Error())
		return err
	}
	return nil
}
```

## Recommended project structure

```text
services/<kotlin-svc>/Dockerfile                     agent + OTEL_* env
services/<go-svc>/internal/platform/telemetry/       SDK setup, propagator
services/<go-svc>/internal/adapters/kafka/tracing.go header carrier, consumer spans
infrastructure/monitoring/otel-collector.yaml
```

## Best practices

- Span names: `HTTP METHOD /route`, `<topic> process`, `<UseCase>`; low cardinality.
- Attributes follow OTel semantic conventions; CommerceFlow-specific ones prefixed
  `commerceflow.`.
- Always end spans (`defer span.End()`); record errors with status.
- Flush on shutdown (`tp.Shutdown(ctx)` in graceful shutdown).
- Return the trace id in API problem responses for support.

## Anti-patterns

- Custom propagation headers (`X-Trace-Id`) instead of W3C.
- Starting a new root span in consumers (breaks the saga trace).
- Order IDs or emails as span names; PII in attributes or baggage.
- Instrumenting domain code with tracing APIs (keep it in adapters/application edges).

## Failure scenarios

| Symptom | Cause | Fix |
|---|---|---|
| Trace stops at outbox | `trace_parent` not captured or header mapping missing | Check outbox row and connector `additional.placement`. |
| Consumer spans are new roots | Header not extracted / wrong propagator | Set TraceContext propagator; extract before starting span. |
| Missing spans on shutdown | Exporter not flushed | Call provider shutdown with timeout. |
| Too many traces | Sampling 100 % in prod | Parent-based ratio sampling; tail sampling for errors. |

## Testing strategy

- Unit: in-memory span exporter (`tracetest.NewInMemoryExporter`) asserts consumer span is a
  child of the injected `traceparent`.
- Integration: outbox row contains a valid `traceparent` after a traced request.
- Stack: Playwright/k6 run, then query Tempo for a trace containing both services.

## Definition of Done

- Service exports traces with correct resource attributes.
- HTTP in/out and Kafka consumers instrumented; outbox carries `traceparent`.
- A placed order produces one trace across services in Tempo.
- Logs carry `trace_id` (`observability`).
