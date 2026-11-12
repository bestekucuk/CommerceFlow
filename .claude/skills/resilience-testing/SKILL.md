---
name: resilience-testing
description: Verify CommerceFlow behaves correctly under failure with Toxiproxy - latency, timeouts, connection resets and outages between services and PostgreSQL, Kafka or HTTP dependencies - in Testcontainers tests (Kotlin and Go) and Compose scenarios in tests/resilience, with expected saga, retry, DLT and idempotency outcomes. Use when adding timeouts, retries, sagas or consumers, and before releases.
---

# Resilience testing

## Purpose

Show, with evidence, that timeouts, retries, idempotent consumers, sagas and outbox/CDC
keep data consistent when dependencies are slow, flaky or down.

## When to use

- After implementing retries, circuit breakers, saga timeouts or consumers.
- When a production incident reveals an untested failure mode.
- Release readiness.

## Prerequisites

- `testcontainers`, `saga-pattern`, `retry-and-dead-letter-queue`, `idempotent-consumer`.
- Toxiproxy image `ghcr.io/shopify/toxiproxy:2.9.0` (pin; match Compose).

## Concepts and architecture

```text
service ──> toxiproxy:<proxyPort> ──> postgres:5432 / payment-provider-stub:8080 / kafka
                 ▲ toxics: latency, timeout, reset_peer, bandwidth, limit_data; proxy enable/disable
```

**Toxics:** `latency` (+jitter), `timeout` (stop data, close after N ms), `reset_peer`,
`bandwidth`, `slow_close`, `limit_data`. Disabling a proxy simulates a hard outage.

**Kafka caveat:** clients connect to advertised listeners after bootstrap, so a single proxy
in front of Kafka does not intercept all traffic. Either configure a listener whose
advertised address is the proxy, or test Kafka failures by pausing the broker container
(`docker pause`) instead.

**Scenario catalogue (`tests/resilience/README.md`)**

| # | Fault | Expected outcome |
|---|---|---|
| R1 | order-service ↔ PostgreSQL latency 2 s | API returns 503 within timeout; no partial writes; recovers when removed. |
| R2 | inventory-service DB down 30 s while commands arrive | Blocking retries succeed after recovery; no DLT; each reservation once. |
| R3 | Payment provider timeout | Saga: `AuthorizePayment` times out → `ReleaseInventory` → order `REJECTED`. |
| R4 | Duplicate delivery of `InventoryReserved` | One state transition; inbox records one row. |
| R5 | Debezium connector stopped 5 min | Orders accepted; events delayed; all delivered after restart; slot lag alert fired. |
| R6 | Broker paused 60 s | Consumers resume; no message loss; lag drains. |

## Step-by-step workflow

1. Pick a scenario and write the expected outcome *before* running it.
2. Route the dependency through Toxiproxy (Testcontainers network or Compose override).
3. Establish steady state (happy-path request succeeds).
4. Inject the fault; drive traffic.
5. Assert outcomes: HTTP responses, final saga states, inbox/outbox counts, DLT content.
6. Remove the fault; assert recovery and no lingering inconsistency.

## Practical code examples

Kotlin + Testcontainers (`org.testcontainers:toxiproxy`, `eu.rekawek.toxiproxy:toxiproxy-java`):

```kotlin
@Testcontainers
@Tag("resilience")
class OrderDbLatencyIT {
    companion object {
        val network: Network = Network.newNetwork()

        @Container @JvmStatic
        val postgres = PostgreSQLContainer("postgres:16-alpine").withNetwork(network).withNetworkAliases("postgres")

        @Container @JvmStatic
        val toxiproxy = ToxiproxyContainer("ghcr.io/shopify/toxiproxy:2.9.0").withNetwork(network)

        lateinit var dbProxy: Proxy

        @JvmStatic @DynamicPropertySource
        fun props(registry: DynamicPropertyRegistry) {
            val client = ToxiproxyClient(toxiproxy.host, toxiproxy.controlPort)
            dbProxy = client.createProxy("postgres", "0.0.0.0:8666", "postgres:5432")
            registry.add("spring.datasource.url") {
                "jdbc:postgresql://${toxiproxy.host}:${toxiproxy.getMappedPort(8666)}/${postgres.databaseName}"
            }
            registry.add("spring.datasource.username", postgres::getUsername)
            registry.add("spring.datasource.password", postgres::getPassword)
        }
    }

    @Test
    fun `slow database returns 503 within the timeout and writes nothing`() {
        dbProxy.toxics().latency("db-latency", ToxicDirection.DOWNSTREAM, 2_000)
        try {
            val response = client.placeOrder(aRequest())
            assertThat(response.statusCode.value()).isEqualTo(503)
            assertThat(response.elapsed()).isLessThan(Duration.ofMillis(1_500))
        } finally {
            dbProxy.toxics().get("db-latency").remove()
        }
        assertThat(countOrders()).isZero()
    }
}
```

(The test assumes the service sets a JDBC/query timeout below 1.5 s — that is the behaviour
under test.)

Go (`github.com/Shopify/toxiproxy/v2/client`):

```go
func TestReservation_RecoversAfterDatabaseOutage(t *testing.T) {
	tp := toxiproxy.NewClient(toxiproxyAddr) // control API, e.g. localhost:8474
	proxy, err := tp.CreateProxy("inventory-db", "0.0.0.0:26432", "postgres:5432")
	if err != nil {
		t.Fatal(err)
	}
	defer proxy.Delete()

	if err := proxy.Disable(); err != nil { // hard outage
		t.Fatal(err)
	}
	publishReserveCommand(t, "o-r2", "SKU-1", 1)
	time.AfterFunc(10*time.Second, func() { _ = proxy.Enable() })

	waitFor(t, 60*time.Second, func() bool { return replyStatus(t, "o-r2") == "InventoryReserved" })
	if n := reservationsFor(t, "o-r2"); n != 1 {
		t.Fatalf("reservations = %d, want 1", n)
	}
	if n := dltCount(t, "cf.inventory.commands.v1.inventory-service.dlt"); n != 0 {
		t.Fatalf("unexpected DLT messages: %d", n)
	}
}
```

Adding latency with jitter in Go:

```go
_, err = proxy.AddToxic("lat", "latency", "downstream", 1.0, toxiproxy.Attributes{"latency": 2000, "jitter": 500})
```

Compose scenario (CLI against the shared stack):

```bash
docker compose exec toxiproxy /toxiproxy-cli toxic add -t timeout -a timeout=5000 payment-provider
# run tests/resilience/r3-payment-timeout.sh, then:
docker compose exec toxiproxy /toxiproxy-cli toxic remove -n timeout_downstream payment-provider
```

## Recommended project structure

```text
tests/resilience/
  README.md                scenario catalogue R1..Rn with expected outcomes
  compose.toxiproxy.yml    override routing dependencies through toxiproxy
  toxiproxy.json           proxy definitions
  r3-payment-timeout.sh    scenario drivers / Playwright or API checks
services/<svc>/src/test/... *ResilienceIT.kt | *_resilience_test.go   (service-local faults)
```

## Best practices

- State expected outcomes first; a resilience test without an assertion is a demo.
- Always remove toxics in `finally`/`defer`.
- Assert data consistency after recovery (counts, states), not just "no exception".
- Keep service-local fault tests (one dependency) in the service; multi-service scenarios in
  `tests/resilience`.
- Run on a schedule; failures are high priority.

## Anti-patterns

- Fault injection in shared environments without coordination.
- Asserting only on logs.
- Sleeping fixed durations instead of polling for recovery.
- Testing Kafka through a naive single proxy and concluding it is resilient.

## Failure scenarios

This skill tests failure scenarios; see the catalogue above. If a scenario fails, file a
defect to the owning service with the trace id and the scenario number.

## Testing strategy

Service-local resilience tests run in the service's integration suite (tagged). Stack-level
scenarios run nightly against Compose and before releases.

## Definition of Done

- Scenario documented with fault, traffic and expected outcome.
- Test injects the fault via Toxiproxy (or container pause for Kafka) and asserts outcomes
  and recovery.
- Toxics cleaned up; test repeatable.
