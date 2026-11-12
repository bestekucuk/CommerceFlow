package kafka

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"strconv"
	"sync/atomic"
	"time"

	"github.com/twmb/franz-go/pkg/kgo"
	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"

	"github.com/commerceflow/commerceflow/services/inventory-service/internal/application"
)

// Topic and consumer group of this consumer.
const (
	Topic    = "cf.product.events.v1"
	Group    = "inventory-service"
	DLTTopic = Topic + ".inventory-service.dlt"
)

// Handler processes one decoded ProductCreated event.
type Handler interface {
	Handle(ctx context.Context, e application.ProductCreated) (application.Outcome, error)
}

// Config tunes the consumer.
type Config struct {
	Brokers []string
	// Backoff for transient failures: first wait, doubled up to MaxBackoff. Retries continue
	// until the failure clears or shutdown begins; the record is never skipped.
	InitialBackoff time.Duration
	MaxBackoff     time.Duration
	// ShutdownGrace bounds the finishing of an in-flight record after shutdown starts.
	ShutdownGrace time.Duration
}

// Consumer reads ProductCreated events with at-least-once delivery: offsets are committed
// only after the database transaction committed. Duplicates are removed by the inbox in
// the handler; the combination gives effectively-once EFFECTS, not exactly-once delivery.
type Consumer struct {
	cfg     Config
	client  *kgo.Client
	decoder *Decoder
	handler Handler
	metrics *Metrics
	log     *slog.Logger
	healthy atomic.Bool
	tracer  trace.Tracer
}

// NewConsumer creates the Kafka client (manual commits, read_committed).
func NewConsumer(cfg Config, decoder *Decoder, handler Handler, metrics *Metrics, log *slog.Logger) (*Consumer, error) {
	if cfg.InitialBackoff <= 0 {
		cfg.InitialBackoff = 500 * time.Millisecond
	}
	if cfg.MaxBackoff <= 0 {
		cfg.MaxBackoff = 30 * time.Second
	}
	if cfg.ShutdownGrace <= 0 {
		cfg.ShutdownGrace = 10 * time.Second
	}
	cl, err := kgo.NewClient(
		kgo.SeedBrokers(cfg.Brokers...),
		kgo.ConsumerGroup(Group),
		kgo.ConsumeTopics(Topic),
		kgo.DisableAutoCommit(),
		kgo.FetchIsolationLevel(kgo.ReadCommitted()),
		kgo.ConsumeResetOffset(kgo.NewOffset().AtStart()),
		kgo.BlockRebalanceOnPoll(),
	)
	if err != nil {
		return nil, fmt.Errorf("kafka client: %w", err)
	}
	c := &Consumer{cfg: cfg, client: cl, decoder: decoder, handler: handler, metrics: metrics, log: log,
		tracer: otel.Tracer("inventory-service/kafka")}
	c.healthy.Store(true)
	return c, nil
}

// Healthy is false while the consumer is retrying a transient failure.
func (c *Consumer) Healthy() bool { return c.healthy.Load() }

// Run consumes until ctx is cancelled, then finishes the in-flight record, commits what
// was processed and leaves the group.
func (c *Consumer) Run(ctx context.Context) error {
	defer c.client.Close()
	for {
		fetches := c.client.PollFetches(ctx)
		if ctx.Err() != nil {
			c.client.AllowRebalance()
			return nil
		}
		if errs := fetches.Errors(); len(errs) > 0 {
			for _, fe := range errs {
				c.log.WarnContext(ctx, "fetch error", "topic", fe.Topic, "partition", fe.Partition, "err", fe.Err)
			}
		}
		var done []*kgo.Record
		var stopErr error
		fetches.EachPartition(func(p kgo.FetchTopicPartition) {
			if stopErr != nil {
				return
			}
			for _, r := range p.Records {
				if ctx.Err() != nil { // shutdown: do not start another record
					stopErr = ctx.Err()
					return
				}
				if err := c.process(ctx, r); err != nil {
					stopErr = err // shutdown during retry: do not commit this or later records
					return
				}
				done = append(done, r)
			}
		})
		// Commit with a context that survives shutdown, so finished work is not redone.
		commitCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 5*time.Second)
		if len(done) > 0 {
			if err := c.client.CommitRecords(commitCtx, done...); err != nil {
				c.log.ErrorContext(ctx, "offset commit failed; records will be redelivered", "err", err)
			}
		}
		cancel()
		c.client.AllowRebalance()
		if stopErr != nil {
			return nil
		}
	}
}

// process handles one record: decode, validate, handle with retries, or dead-letter.
// It returns an error only when shutdown interrupted a retry.
func (c *Consumer) process(ctx context.Context, r *kgo.Record) error {
	start := time.Now()
	hdr := headers(r)
	rctx := otel.GetTextMapPropagator().Extract(ctx, headerCarrier(r.Headers))
	rctx, span := c.tracer.Start(rctx, Topic+" process", trace.WithSpanKind(trace.SpanKindConsumer),
		trace.WithAttributes(
			attribute.String("messaging.system", "kafka"),
			attribute.String("messaging.destination.name", r.Topic),
			attribute.String("messaging.kafka.consumer.group", Group),
			attribute.Int64("messaging.kafka.message.offset", r.Offset),
			attribute.String("messaging.message.id", hdr["id"]),
		))
	defer span.End()
	log := c.log.With("topic", r.Topic, "partition", r.Partition, "offset", r.Offset, "event_id", hdr["id"])

	if hdr["eventType"] != "ProductCreated" {
		c.metrics.observe(r.Topic, "skipped", start)
		log.DebugContext(rctx, "skipping event type not handled here", "event_type", hdr["eventType"])
		return nil
	}

	var event application.ProductCreated
	decoded := false
	backoff := c.cfg.InitialBackoff
	for attempt := 1; ; attempt++ {
		var err error
		if !decoded {
			event, err = c.decode(rctx, r, hdr)
			if err == nil {
				decoded = true
				span.SetAttributes(attribute.String("commerceflow.correlation_id", event.CorrelationID),
					attribute.String("commerceflow.product.id", event.ProductID))
				log = log.With("correlation_id", event.CorrelationID, "product_id", event.ProductID)
			}
		}
		var outcome application.Outcome
		if err == nil {
			// the transaction must finish even if shutdown starts meanwhile
			hctx, cancel := context.WithTimeout(context.WithoutCancel(rctx), c.cfg.ShutdownGrace)
			outcome, err = c.handler.Handle(hctx, event)
			cancel()
		}
		if err == nil {
			c.healthy.Store(true)
			c.metrics.observe(r.Topic, string(outcome), start)
			log.InfoContext(rctx, "event handled", "outcome", outcome, "attempt", attempt)
			return nil
		}
		if isPermanent(err) {
			span.RecordError(err)
			span.SetStatus(codes.Error, "dead-lettered")
			dErr := c.deadLetter(rctx, r, err, attempt)
			if dErr == nil {
				c.healthy.Store(true)
				c.metrics.observe(r.Topic, "dlt", start)
				log.ErrorContext(rctx, "event dead-lettered", "err", err)
				return nil
			}
			err = dErr // the DLT is unavailable: retry like any transient failure
		}
		// transient: retry with capped exponential backoff until it clears or shutdown begins.
		// Let pending group rebalances proceed meanwhile (BlockRebalanceOnPoll would otherwise
		// stall the whole group); if this partition moves, its new owner redelivers the record
		// and the inbox prevents a second effect, while our later commit for it fails harmlessly.
		c.client.AllowRebalance()
		c.healthy.Store(false)
		c.metrics.Retries.WithLabelValues(r.Topic).Inc()
		log.WarnContext(rctx, "transient failure, retrying", "attempt", attempt, "backoff", backoff, "err", err)
		select {
		case <-ctx.Done():
			span.SetStatus(codes.Error, "interrupted by shutdown")
			return ctx.Err()
		case <-time.After(backoff):
		}
		backoff = min(backoff*2, c.cfg.MaxBackoff)
	}
}

// decode turns the record into the application event and checks that headers, key and
// envelope agree. Disagreement is permanent (the record can never become valid).
func (c *Consumer) decode(ctx context.Context, r *kgo.Record, hdr map[string]string) (application.ProductCreated, error) {
	event, err := c.decoder.DecodeProductCreated(ctx, r.Value)
	if err != nil {
		return event, err
	}
	if hdr["id"] != "" && hdr["id"] != event.EventID {
		return event, fmt.Errorf("%w: header id %s differs from metadata.eventId %s", application.ErrInvalidEvent, hdr["id"], event.EventID)
	}
	if string(r.Key) != event.AggregateID {
		return event, fmt.Errorf("%w: key %q differs from aggregateId %q", application.ErrInvalidEvent, r.Key, event.AggregateID)
	}
	return event, nil
}

func isPermanent(err error) bool {
	return errors.Is(err, application.ErrInvalidEvent) || errors.Is(err, ErrUndecodable)
}

func (c *Consumer) deadLetter(ctx context.Context, r *kgo.Record, cause error, attempts int) error {
	dlt := &kgo.Record{
		Topic: DLTTopic,
		Key:   r.Key,
		Value: r.Value,
		Headers: append(append([]kgo.RecordHeader{}, r.Headers...),
			kgo.RecordHeader{Key: "dlt-original-topic", Value: []byte(r.Topic)},
			kgo.RecordHeader{Key: "dlt-original-partition", Value: []byte(strconv.Itoa(int(r.Partition)))},
			kgo.RecordHeader{Key: "dlt-original-offset", Value: []byte(strconv.FormatInt(r.Offset, 10))},
			kgo.RecordHeader{Key: "dlt-error", Value: []byte(cause.Error())},
			kgo.RecordHeader{Key: "dlt-attempts", Value: []byte(strconv.Itoa(attempts))},
		),
	}
	pctx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 10*time.Second)
	defer cancel()
	if err := c.client.ProduceSync(pctx, dlt).FirstErr(); err != nil {
		return fmt.Errorf("publish to %s: %w", DLTTopic, err)
	}
	return nil
}

func headers(r *kgo.Record) map[string]string {
	m := make(map[string]string, len(r.Headers))
	for _, h := range r.Headers {
		m[h.Key] = string(h.Value)
	}
	return m
}

// headerCarrier lets the OTel propagator read W3C trace context from Kafka headers.
type headerCarrier []kgo.RecordHeader

func (h headerCarrier) Get(key string) string {
	for _, hd := range h {
		if hd.Key == key {
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
