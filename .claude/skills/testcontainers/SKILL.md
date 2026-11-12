---
name: testcontainers
description: Run CommerceFlow integration tests against real PostgreSQL, Kafka, Schema Registry, Redis and Toxiproxy with Testcontainers - Spring Boot @ServiceConnection and dynamic properties in Kotlin, testcontainers-go modules in Go, container reuse, Flyway/migrate setup, wait strategies and Windows/CI notes. Use when writing adapter or service-level integration tests.
---

# Testcontainers

## Purpose

Integration tests that use the same infrastructure as production, started on demand by
the test itself, so each service's suite runs from its own folder with only Docker.

## When to use

- Testing repositories, outbox/inbox, Kafka listeners/consumers, Redis adapters.
- Service-level tests (`@SpringBootTest`, Go `main`-level tests).

## Prerequisites

- Docker running (Docker Desktop on Windows/macOS).
- `unit-integration-testing` for layering.

## Concepts and architecture

- Containers are started per test class (Kotlin) or per package via `TestMain` (Go) and
  shared across tests in it.
- Images are pinned to the versions used in `docker-compose.yml`
  (`postgres:16-alpine`, Kafka, Schema Registry).
- Schema is created by the real migrations (Flyway/migrate), never by hand-written test DDL.
- Each test cleans the tables it uses (or uses unique IDs) to stay order-independent.

## Step-by-step workflow

1. Add Testcontainers dependencies (Kotlin) / modules (Go).
2. Create a shared container definition (base class or `TestMain`).
3. Wire connection settings (`@ServiceConnection` / `@DynamicPropertySource` / env).
4. Run migrations before tests.
5. Write tests; await asynchronous results with Awaitility/polling.
6. Run locally and in CI.

## Practical code examples

Kotlin base class (Spring Boot 3.1+):

```kotlin
@Testcontainers
@SpringBootTest
@Tag("integration")
abstract class IntegrationTest {
    companion object {
        @Container @ServiceConnection @JvmStatic
        val postgres = PostgreSQLContainer("postgres:16-alpine")

        @Container @JvmStatic
        val kafka = ConfluentKafkaContainer("confluentinc/cp-kafka:7.7.1")

        @JvmStatic @DynamicPropertySource
        fun kafkaProps(registry: DynamicPropertyRegistry) {
            registry.add("spring.kafka.bootstrap-servers") { kafka.bootstrapServers }
            registry.add("spring.kafka.properties.schema.registry.url") { "mock://order-service-tests" }
        }
    }
}
```

`mock://` uses Confluent's in-memory registry for serializer tests; use a real
Schema Registry container (`GenericContainer("confluentinc/cp-schema-registry:7.7.1")`
on the Kafka network) when testing compatibility or cross-process flows.
`ConfluentKafkaContainer` is in `org.testcontainers.kafka` (Testcontainers 1.20+).

Outbox atomicity test:

```kotlin
class PlaceOrderIT : IntegrationTest() {
    @Autowired lateinit var placeOrder: PlaceOrder
    @Autowired lateinit var jdbc: JdbcClient

    @Test
    fun `order and outbox row are committed together`() {
        val id = placeOrder.handle(aPlaceOrderCommand())
        val rows = jdbc.sql("SELECT type, aggregate_id, topic FROM outbox WHERE aggregate_id = :id")
            .param("id", id.value.toString()).query().listOfRows()
        assertThat(rows).singleElement().satisfies({
            assertThat(it["type"]).isEqualTo("OrderCreated")
            assertThat(it["topic"]).isEqualTo("cf.order.events.v1")
        })
    }
}
```

Go with testcontainers-go (`github.com/testcontainers/testcontainers-go/modules/postgres`):

```go
//go:build integration

var testPool *pgxpool.Pool

func TestMain(m *testing.M) {
	ctx := context.Background()
	ctr, err := tcpostgres.Run(ctx, "postgres:16-alpine",
		tcpostgres.WithDatabase("inventory_db"),
		tcpostgres.WithUsername("inventory_migrator"),
		tcpostgres.WithPassword("test"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").WithOccurrence(2).WithStartupTimeout(60*time.Second)),
	)
	if err != nil {
		log.Fatalf("start postgres: %v", err)
	}
	dsn, err := ctr.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		log.Fatalf("dsn: %v", err)
	}
	if err := migrateUp(dsn); err != nil {                 // runs ../../migrations
		log.Fatalf("migrate: %v", err)
	}
	testPool, err = pgxpool.New(ctx, dsn)
	if err != nil {
		log.Fatalf("pool: %v", err)
	}
	code := m.Run()
	testPool.Close()
	_ = testcontainers.TerminateContainer(ctr)
	os.Exit(code)
}

func TestStockRepository_ReserveIsAtomic(t *testing.T) {
	ctx := context.Background()
	seedStock(t, testPool, "SKU-1", 1)
	var wins atomic.Int32
	var wg sync.WaitGroup
	for range 10 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := postgres.InTx(ctx, testPool, func(tx pgx.Tx) error {
				return repo.Reserve(ctx, tx, "SKU-1", 1)
			}); err == nil {
				wins.Add(1)
			}
		}()
	}
	wg.Wait()
	if wins.Load() != 1 {
		t.Fatalf("expected exactly 1 successful reservation, got %d", wins.Load())
	}
}
```

Imports: `tcpostgres "github.com/testcontainers/testcontainers-go/modules/postgres"`,
`"github.com/testcontainers/testcontainers-go/wait"`, and the service's own
`internal/adapters/postgres` package (which provides `InTx`).

Awaiting async results (Kotlin, Awaitility):

```kotlin
await().atMost(Duration.ofSeconds(10)).untilAsserted {
    assertThat(inboxCount(eventId)).isEqualTo(1)
}
```

## Recommended project structure

```text
services/<kotlin-svc>/src/test/kotlin/.../support/IntegrationTest.kt
services/<go-svc>/internal/adapters/postgres/main_test.go   (TestMain, //go:build integration)
```

## Best practices

- Pin image tags; match Compose versions.
- One container set per test class/package; reset data, not containers.
- Use real migrations; fail the test if migration fails.
- Enable reuse locally only (`testcontainers.reuse.enable=true` in
  `~/.testcontainers.properties`), never in CI.
- Windows: Docker Desktop with WSL 2; avoid host-path volume mounts in tests.

## Anti-patterns

- H2/SQLite instead of PostgreSQL.
- Embedded Kafka for consumer tests that depend on real broker behaviour (rebalances,
  transactions) — use a container.
- `latest` image tags.
- Containers started in `@BeforeEach` (slow).
- Tests that share rows without cleanup.

## Failure scenarios

| Scenario | Symptom | Fix |
|---|---|---|
| Docker not running | `Could not find a valid Docker environment` | Start Docker; CI must provide Docker. |
| Port conflicts | Random failures | Never bind fixed host ports; use mapped ports. |
| Slow startup in CI | Timeouts | Increase startup timeout; pre-pull images. |
| Ryuk blocked in CI | Containers left running | Allow Ryuk or set cleanup explicitly. |

## Testing strategy

Testcontainers is the integration layer of `unit-integration-testing`; Toxiproxy
containers extend it for `resilience-testing`.

## Definition of Done

- Adapter/service tests run against real containers with pinned images.
- Schema created by real migrations.
- Tests independent of order; async waits bounded.
- Suite passes from the service folder locally and in CI.
