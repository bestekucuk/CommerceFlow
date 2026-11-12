---
name: unit-integration-testing
description: Write CommerceFlow unit and service-level integration tests - the test pyramid per service, JUnit 5 with AssertJ and MockK for Kotlin, table-driven Go tests, fakes for ports, what to integration-test against real PostgreSQL and Kafka, naming, and where tests live in the monorepo. Use whenever code is added or changed in a service.
---

# Unit and integration testing

## Purpose

Fast feedback on business rules and confidence that adapters work against real
infrastructure — runnable from each service folder alone.

## When to use

- Every code change in `services/*`.
- Deciding the right test layer for a behaviour.

## Prerequisites

- `clean-architecture` (layers determine test types), `testcontainers`.

## Concepts and architecture

| Layer | Tests | Tools | Speed |
|---|---|---|---|
| domain | Unit: invariants, events | JUnit 5 + AssertJ / Go `testing` | ms |
| application | Unit with fakes of ports | MockK or hand-written fakes / Go fakes | ms |
| adapters | Integration with real infra | Testcontainers PostgreSQL, Kafka, Schema Registry | seconds |
| service | `@SpringBootTest` / `main`-level test: HTTP in → DB + outbox out | Testcontainers | seconds |
| cross-service | not here → `tests/integration` | Compose | minutes |

Location: Kotlin `services/<svc>/src/test/kotlin/...`, Go `*_test.go` next to the code,
integration tests behind a build tag or naming (`*IT.kt`, `//go:build integration`) so
unit tests stay fast.

## Step-by-step workflow

1. Write the domain rule test first (allowed + rejected case).
2. Test the use case with fakes: correct port calls and events recorded.
3. Integration-test each adapter you touched with Testcontainers.
4. Add one service-level test per endpoint/consumer for the happy path and one failure.
5. Run all from the service folder: `./gradlew test` / `go test -race ./...`
   (+ integration tag).

## Practical code examples

Kotlin domain test (JUnit 5 + AssertJ):

```kotlin
class OrderTest {
    @Test
    fun `confirm requires authorized payment`() {
        val order = anOrder(status = OrderStatus.INVENTORY_RESERVED)
        assertThatThrownBy { order.confirm() }
            .isInstanceOf(IllegalStateException::class.java)
            .hasMessageContaining("INVENTORY_RESERVED")
    }

    @Test
    fun `confirm records OrderConfirmed with total`() {
        val order = anOrder(status = OrderStatus.PAYMENT_AUTHORIZED, lines = listOf(line(qty = 2, price = 500)))
        order.confirm()
        assertThat(order.pullEvents()).singleElement()
            .isEqualTo(OrderDomainEvent.Confirmed(order.id, Money(1000, EUR)))
    }
}
```

Use case with a fake (preferred over mocks for repositories):

```kotlin
class InMemoryOrders : OrderRepository {
    val saved = mutableMapOf<OrderId, Order>()
    override fun save(order: Order) { saved[order.id] = order }
    override fun findById(id: OrderId) = saved[id]
}

class PlaceOrderTest {
    private val orders = InMemoryOrders()
    private val events = mockk<OrderEvents>(relaxed = true)

    @Test
    fun `placing an order saves it and records OrderPlaced`() {
        val id = PlaceOrder(orders, events) { FIXED_UUID }.handle(command())
        assertThat(orders.saved).containsKey(id)
        verify { events.record(match { it.single() is OrderDomainEvent.Placed }) }
    }
}
```

Go use-case test with a fake:

```go
type fakeStock struct{ items map[domain.SKU]*domain.StockItem }

func (f *fakeStock) Get(_ context.Context, sku domain.SKU) (*domain.StockItem, error) {
	if it, ok := f.items[sku]; ok {
		return it, nil
	}
	return nil, domain.ErrNotFound
}

func TestReserveStock_EmitsFailureWhenInsufficient(t *testing.T) {
	stock := &fakeStock{items: map[domain.SKU]*domain.StockItem{"SKU-1": {SKU: "SKU-1", OnHand: 1}}}
	out := &fakeOutbox{}
	uc := application.NewReserveStock(stock, out)

	err := uc.Handle(context.Background(), application.ReserveCommand{OrderID: "o-1", SKU: "SKU-1", Qty: 2})

	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got := out.types(); !slices.Equal(got, []string{"InventoryReservationFailed"}) {
		t.Fatalf("outbox = %v, want [InventoryReservationFailed]", got)
	}
}
```

Gradle: separate unit and integration tasks (optional):

```kotlin
tasks.test { useJUnitPlatform { excludeTags("integration") } }
val integrationTest by tasks.registering(Test::class) {
    useJUnitPlatform { includeTags("integration") }
    testClassesDirs = sourceSets.test.get().output.classesDirs
    classpath = sourceSets.test.get().runtimeClasspath
    shouldRunAfter(tasks.test)
}
tasks.check { dependsOn(integrationTest) }
```

## Recommended project structure

```text
services/<kotlin-svc>/src/test/kotlin/com/commerceflow/<ctx>/
  domain/  application/  adapters/ (tagged integration)  ArchitectureTest.kt  support/ (builders, fakes)
services/<go-svc>/internal/**/x_test.go   integration files: //go:build integration
```

## Best practices

- Test behaviour, not implementation details; one reason to fail per test.
- Test data builders (`anOrder(...)`) instead of large fixtures.
- Inject `Clock` and ID generators for determinism.
- No `Thread.sleep`/`time.Sleep` for async; use Awaitility / polling with timeouts.
- Keep unit suites under a few seconds per service.

## Anti-patterns

- Mocking value objects or the domain.
- Mocking the database in "integration" tests.
- Tests depending on execution order or shared mutable state.
- Asserting on log output instead of behaviour.
- Cross-service tests inside a service folder.

## Failure scenarios

| Scenario | Handling |
|---|---|
| Flaky async test | Replace sleeps with bounded polling; check for shared state. |
| Docker unavailable | Integration tests skipped with a clear message locally; mandatory in CI. |
| Slow suite | Move logic tests down the pyramid; reuse containers per test class. |

## Testing strategy

This skill *is* the strategy for service-local tests; cross-service layers are covered by
`contract-testing`, `playwright-e2e`, `performance-testing` and `resilience-testing`.

## Definition of Done

- New domain rules have unit tests (allowed and rejected cases).
- Use cases tested with fakes; adapters tested with Testcontainers.
- All tests pass from the service folder; no sleeps; deterministic time and IDs.
