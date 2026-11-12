package kafka

import (
	"time"

	"github.com/prometheus/client_golang/prometheus"
)

// Metrics are the consumer's processing metrics (exposed on /metrics).
type Metrics struct {
	Processed *prometheus.CounterVec
	Duration  *prometheus.HistogramVec
	Retries   *prometheus.CounterVec
}

// NewMetrics registers the consumer metrics.
func NewMetrics(reg prometheus.Registerer) *Metrics {
	m := &Metrics{
		Processed: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "commerceflow_messages_processed_total",
			Help: "Kafka records finished, by outcome: processed, duplicate, skipped, dlt.",
		}, []string{"topic", "outcome"}),
		Duration: prometheus.NewHistogramVec(prometheus.HistogramOpts{
			Name:    "commerceflow_message_processing_seconds",
			Help:    "Time from receiving a record to finishing it, including retries.",
			Buckets: prometheus.DefBuckets,
		}, []string{"topic", "outcome"}),
		Retries: prometheus.NewCounterVec(prometheus.CounterOpts{
			Name: "commerceflow_message_retries_total",
			Help: "Transient processing failures that were retried.",
		}, []string{"topic"}),
	}
	reg.MustRegister(m.Processed, m.Duration, m.Retries)
	return m
}

func (m *Metrics) observe(topic, outcome string, start time.Time) {
	m.Processed.WithLabelValues(topic, outcome).Inc()
	m.Duration.WithLabelValues(topic, outcome).Observe(time.Since(start).Seconds())
}
