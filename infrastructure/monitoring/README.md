# infrastructure/monitoring

Status: **implemented for local development** — see `infrastructure/README.md`.

| Path | Purpose |
|---|---|
| `otel-collector.yaml` | OTLP in; traces → Tempo, metrics → Prometheus (:8889), logs → Loki |
| `prometheus/prometheus.yml` | Scrape config (collector, exporters, Loki, Tempo, Grafana) |
| `loki.yaml`, `tempo.yaml` | Single-binary local configs |
| `grafana/provisioning/` | Datasources (Prometheus, Loki, Tempo) and dashboard provider |
| `grafana/dashboards/` | Infrastructure health, Kafka health, Consumer lag, PostgreSQL health |
