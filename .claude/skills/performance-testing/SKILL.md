---
name: performance-testing
description: Plan and run CommerceFlow performance tests with k6 in tests/performance - workload models (browse, checkout saga, price lookup), scenarios and executors, thresholds as SLOs, checks, test data, running via Docker, exporting metrics to Prometheus/Grafana, and interpreting results alongside traces and consumer lag. Use before releases, after performance-sensitive changes, or to size a service.
---

# Performance testing

## Purpose

Know how each service and the checkout saga behave under realistic and peak load, and
catch regressions before production.

## When to use

- New or changed hot paths (catalog browse, price lookup, reservation).
- Capacity planning for a service (replicas, partitions, DB pool).
- Release candidates (baseline comparison).

## Prerequisites

- Stack running (Compose locally or a dedicated perf environment — never production).
- Monitoring stack (`observability`) to watch latency, saturation and consumer lag.
- Owner: `test-engineer`; services' engineers for analysis.

## Concepts and architecture

| Test type | Goal | Executor |
|---|---|---|
| Smoke | Script works, baseline numbers | `constant-vus`, 1–2 VUs, 1 min |
| Load | Expected peak, SLO check | `ramping-arrival-rate` |
| Stress | Find breaking point | arrival rate ramps beyond peak |
| Soak | Leaks, slot/WAL growth, lag drift | constant rate, hours |
| Spike | Autoscaling, queue absorption | sudden ramp |

**Open model** (arrival rate) for HTTP APIs: requests keep coming even if the system slows,
as in reality. **Asynchronous outcome**: measure saga completion time separately (poll
order status) and watch Kafka consumer lag.

Initial SLO proposals (to confirm in an ADR): catalog `GET` p95 < 200 ms; price quote p95
< 100 ms; place order `POST` p95 < 300 ms; order confirmed p95 < 5 s; error rate < 0.5 %.

## Step-by-step workflow

1. Define the workload: endpoints, mix, arrival rates, data distribution.
2. Prepare test data via APIs (seed script), not via databases.
3. Write the k6 script with scenarios, checks and thresholds.
4. Run a smoke test; then load; record baseline results in the PR/backlog.
5. Watch Grafana during the run: latency, CPU, DB connections, consumer lag, slot lag.
6. Analyse bottlenecks with traces (`distributed-tracing`); file issues per service.

## Practical code examples

`tests/performance/checkout.js`:

```js
import http from "k6/http";
import { check, sleep } from "k6";
import { Trend } from "k6/metrics";
import { uuidv4 } from "https://jslib.k6.io/k6-utils/1.4.0/index.js";

const ORDER = __ENV.ORDER_API_URL || "http://localhost:8082";
const CATALOG = __ENV.CATALOG_API_URL || "http://localhost:8081";
const TOKEN = __ENV.TOKEN;
const sagaDuration = new Trend("saga_confirmed_ms", true);

export const options = {
  scenarios: {
    browse: {
      executor: "ramping-arrival-rate", exec: "browse", timeUnit: "1s",
      startRate: 10, preAllocatedVUs: 50, maxVUs: 200,
      stages: [{ target: 100, duration: "2m" }, { target: 100, duration: "5m" }, { target: 0, duration: "1m" }],
    },
    checkout: {
      executor: "ramping-arrival-rate", exec: "checkout", timeUnit: "1s",
      startRate: 1, preAllocatedVUs: 20, maxVUs: 100,
      stages: [{ target: 10, duration: "2m" }, { target: 10, duration: "5m" }, { target: 0, duration: "1m" }],
    },
  },
  thresholds: {
    "http_req_duration{scenario:browse}": ["p(95)<200"],
    "http_req_duration{name:place_order}": ["p(95)<300"],
    "saga_confirmed_ms": ["p(95)<5000"],
    "http_req_failed": ["rate<0.005"],
    "checks": ["rate>0.99"],
  },
};

const auth = { headers: { Authorization: `Bearer ${TOKEN}`, "Content-Type": "application/json" } };

export function browse() {
  const res = http.get(`${CATALOG}/v1/products?limit=24`, { tags: { name: "list_products" } });
  check(res, { "list 200": (r) => r.status === 200 });
}

export function checkout() {
  const started = Date.now();
  const res = http.post(`${ORDER}/v1/orders`,
    JSON.stringify({ lines: [{ sku: `PERF-${Math.floor(Math.random() * 1000)}`, quantity: 1 }] }),
    { ...auth, headers: { ...auth.headers, "Idempotency-Key": uuidv4() }, tags: { name: "place_order" } });
  if (!check(res, { "accepted 202": (r) => r.status === 202 })) return;

  const id = res.json("orderId");
  for (let i = 0; i < 20; i++) {
    sleep(0.5);
    const s = http.get(`${ORDER}/v1/orders/${id}`, { ...auth, tags: { name: "order_status" } });
    const status = s.json("status");
    if (status === "CONFIRMED" || status === "REJECTED") {
      sagaDuration.add(Date.now() - started);
      check(status, { "saga confirmed": (st) => st === "CONFIRMED" });
      return;
    }
  }
  check(null, { "saga finished in 10s": () => false });
}
```

Run with Docker (no local install, works on Windows):

```bash
docker run --rm -i --network commerceflow_default \
  -e ORDER_API_URL=http://order-service:8082 -e CATALOG_API_URL=http://product-service:8081 -e TOKEN \
  -v "$PWD/tests/performance:/scripts" grafana/k6:0.54.0 run /scripts/checkout.js
```

Export to Prometheus (remote write receiver enabled):

```bash
K6_PROMETHEUS_RW_SERVER_URL=http://prometheus:9090/api/v1/write k6 run -o experimental-prometheus-rw checkout.js
```

## Recommended project structure

```text
tests/performance/
  checkout.js  browse.js  price-lookup.js
  lib/          auth.js, data.js
  data/         seed definitions (generated, not secrets)
  results/      gitignored
  README.md     how to run, current baselines
```

## Best practices

- Model arrival rates from expected business volume; include think time in closed models.
- Tag requests (`name`) so thresholds and dashboards are per endpoint.
- Thresholds encode SLOs and fail the run (`exit code 99`).
- Warm up before measuring; run long enough to reach steady state (≥ 5 min).
- Compare against a stored baseline; change one variable at a time.

## Anti-patterns

- Load testing production or shared staging without coordination.
- Measuring only averages.
- Unique hot rows for every VU (e.g. all orders on one SKU) unless testing contention on purpose.
- Ignoring asynchronous lag: HTTP fast, saga minutes behind.
- Running k6 on the same machine resources as the system under test and trusting the numbers blindly.

## Failure scenarios

| Observation | Likely cause | Next step |
|---|---|---|
| p95 rises with flat CPU | DB pool or lock contention | Check `pg_stat_activity`, pool metrics, traces. |
| Saga time grows, HTTP fine | Consumer lag | Partitions, consumer concurrency, slow handler. |
| Errors at fixed rate | Rate limits / connection limits | Tune limits, check `max_connections`. |
| Slot lag grows during soak | Debezium throughput | Connector tuning, outbox cleanup. |

## Testing strategy

Smoke on every relevant PR (short, optional), load test before releases, soak monthly or
before major launches. Results recorded in `tests/performance/README.md`.

## Definition of Done

- Script with scenarios, checks and SLO thresholds committed.
- Baseline recorded; run passes thresholds or deviations analysed with traces/metrics.
- Async (saga) latency and consumer lag measured, not just HTTP.
